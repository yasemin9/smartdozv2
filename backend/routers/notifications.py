"""SmartDoz - Bildirim Router (EK1_revize.pdf Modül 2 & 7)

GET  /notifications/pending
    Kullanıcıya ait, önümüzdeki WINDOW_MINUTES dakika içinde zamanı gelecek
    veya gecikmiş 'Bekliyor' / 'Ertelendi' doz loglarını döner.

POST /notifications/snooze/{dose_log_id}
    Verilen dozu kullanıcının seçtiği süre kadar (5/10/15 dk) erteler.
    Hem 'Bekliyor' hem 'Ertelendi' durumundan tekrar erteleye izin verir
    ('tek seferlik' kısıtlaması yoktur).

Flutter frontend bu endpoint'i periyodik olarak polling yaparak
browser Notification API'si üzerinden bildirim gösterir.
Aynı doz için tekrar bildirim göndermemek frontend'in sorumluluğundadır
(_shownIds seti).
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import DoseLog, Medication, User
from schemas import DoseLogResponse, SnoozeRequest

router = APIRouter(prefix="/notifications", tags=["Bildirimler"])

# Bildirim penceresi: şimdiden kaç dakika ilerisine kadar
WINDOW_MINUTES = 15
# Geriye doğru tolerans: gecikmeli dozları yakalamak için
BACK_TOLERANCE_MINUTES = 5

# Snooze'a izin verilen kaynak durumlar (tek-seferlik kısıtlaması kaldırıldı)
_SNOOZE_ALLOWED_FROM = {"Bekliyor", "Ertelendi"}


@router.get(
    "/pending",
    response_model=list[DoseLogResponse],
    summary="Yaklaşan doz bildirimleri",
)
async def get_pending_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Önümüzdeki 15 dakika içinde zamanı gelmiş veya 5 dakikaya kadar
    gecikmeli olan 'Bekliyor' / 'Ertelendi' doz loglarını döner.

    Flutter bu endpoint'i 60 saniyede bir polling yapar.
    Tekrar bildirim gönderimi frontend tarafında yönetilir (_shownIds).
    """
    now = datetime.now()
    window_start = now - timedelta(minutes=BACK_TOLERANCE_MINUTES)
    window_end   = now + timedelta(minutes=WINDOW_MINUTES)

    # Kullanıcıya ait ilaçları al
    meds_res = await db.execute(
        select(Medication).where(Medication.user_id == current_user.id)
    )
    medications = meds_res.scalars().all()
    if not medications:
        return []

    med_ids = [m.id for m in medications]
    med_map = {m.id: m for m in medications}

    # Pencere içindeki bekleyen/ertelenen dozlar
    logs_res = await db.execute(
        select(DoseLog).where(
            DoseLog.medication_id.in_(med_ids),
            DoseLog.status.in_(["Bekliyor", "Ertelendi"]),
            DoseLog.scheduled_time >= window_start,
            DoseLog.scheduled_time <= window_end,
        )
    )
    logs = logs_res.scalars().all()

    return [
        DoseLogResponse(
            id=log.id,
            medication_id=log.medication_id,
            medication_name=med_map[log.medication_id].name,
            dosage_form=med_map[log.medication_id].dosage_form,
            scheduled_time=log.scheduled_time,
            actual_time=log.actual_time,
            status=log.status,
            notes=log.notes,
        )
        for log in sorted(logs, key=lambda l: l.scheduled_time)
        if log.medication_id in med_map
    ]


@router.post(
    "/snooze/{dose_log_id}",
    response_model=DoseLogResponse,
    summary="Dozu ertele (5 / 10 / 15 dk)",
)
async def snooze_dose(
    dose_log_id: int,
    body: SnoozeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Modül 2 (Hatırlatıcı Sistemi) — Gelişmiş Erteleme.

    • 'Bekliyor' veya 'Ertelendi' durumundaki bir dozu kullanıcının
      seçtiği süre (5 / 10 / 15 dakika) kadar erteler.
    • Tek-seferlik kısıtlaması yoktur: 'Ertelendi' durumundaki doz
      tekrar ertelenebilir.
    • Modül 7 (Kullanım Verisi Kaydı): Her erteleme işlemi
      'Ertelendi' durumuyla zaman damgası ve süre bilgisiyle
      PostgreSQL'e kaydedilir (was_postponed=True, notes güncellenir).

    Güvenlik:
        İlaç kaydının current_user'a ait olup olmadığı sorguyla doğrulanır.
    """
    # ── Doz logunu getir
    log_res = await db.execute(select(DoseLog).where(DoseLog.id == dose_log_id))
    log = log_res.scalar_one_or_none()
    if log is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doz logu bulunamadı.",
        )

    # ── Sahiplik kontrolü
    med_res = await db.execute(
        select(Medication).where(
            Medication.id == log.medication_id,
            Medication.user_id == current_user.id,
        )
    )
    medication = med_res.scalar_one_or_none()
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu kayda erişim yetkiniz yok.",
        )

    # ── Durum kontrolü (Bekliyor veya Ertelendi'den ertele)
    if log.status not in _SNOOZE_ALLOWED_FROM:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"'{log.status}' durumundaki doz ertelenemez. "
                f"Yalnızca {_SNOOZE_ALLOWED_FROM} durumları ertelenebilir."
            ),
        )

    # ── Erteleme işlemi
    now = datetime.now()
    new_scheduled = now + timedelta(minutes=body.minutes)

    # Modül 7: Erteleme zaman damgası ve süresini nota ekle
    snooze_note = f"[Ertelendi {now.strftime('%H:%M')} → {new_scheduled.strftime('%H:%M')} ({body.minutes} dk)]"
    if log.notes:
        log.notes = f"{log.notes} | {snooze_note}"
    else:
        log.notes = snooze_note

    log.status = "Ertelendi"
    log.scheduled_time = new_scheduled
    log.was_postponed = True  # Modül 7: davranış analizi bayrağı

    await db.commit()
    await db.refresh(log)

    return DoseLogResponse(
        id=log.id,
        medication_id=log.medication_id,
        medication_name=medication.name,
        dosage_form=medication.dosage_form,
        scheduled_time=log.scheduled_time,
        actual_time=log.actual_time,
        status=log.status,
        notes=log.notes,
    )
