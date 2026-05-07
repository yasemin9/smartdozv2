"""SmartDoz - Doz Takip Router

PATCH /dose-logs/{id}  — Doz durumunu günceller.
Yalnızca kaydın sahibi bu endpoint'i kullanabilir.

State Machine (EK1_revize.pdf s.44 — MPR & Uyum):
    Bekliyor  → Alındı | Atlandı | Ertelendi
    Ertelendi → Alındı | Atlandı          (esnek geri dönüş)
    Alındı    → (terminal — değiştirilemez)
    Atlandı   → (terminal — değiştirilemez)

Modül 2 (Bildirim Sistemi):
    Durum "Atlandı"a geçildiğinde, kullanıcının aktif bakıcılarına
    (caregiver_relationships tablosundaki kişilere) otomatik bildirim
    gönderilir.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import DoseLog, Medication, User, Notification, CaregiverRelationship
from schemas import DoseLogResponse, DoseLogStatusUpdate

router = APIRouter(prefix="/dose-logs", tags=["Doz Takip"])

# Hangi durumdan hangi durumlara geçiş izni var
_ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "Bekliyor":  {"Alındı", "Atlandı", "Ertelendi"},
    "Ertelendi": {"Alındı", "Atlandı"},
    "Alındı":    set(),   # terminal
    "Atlandı":   set(),   # terminal
}


async def _send_missed_dose_notification(
    db: AsyncSession,
    user_id: int,
    dose_log: DoseLog,
    medication: Medication,
):
    """
    İlaç atlandığında bakıcılara bildirim gönder.
    
    İç kullanım için yardımcı fonksiyon.
    """
    # Aktif bakıcıları getir
    caregivers_res = await db.execute(
        select(CaregiverRelationship).where(
            CaregiverRelationship.user_id == user_id,
            CaregiverRelationship.is_active == True,
        )
    )
    caregivers = caregivers_res.scalars().all()
    
    if not caregivers:
        return 0
    
    # Her bakıcı için bildirim oluştur
    scheduled_time_str = dose_log.scheduled_time.strftime("%H:%M")
    
    for caregiver_rel in caregivers:
        notification = Notification(
            user_id=user_id,
            caregiver_id=caregiver_rel.caregiver_user_id,
            dose_log_id=dose_log.id,
            medication_id=medication.id,
            notification_type="MISSED_DOSE",
            title=f"⚠️ İlaç Atlandı: {medication.name}",
            message=(
                f"{medication.name} saat {scheduled_time_str}'de "
                f"alınması gerekirken alınmadı."
            ),
            is_read=False,
        )
        db.add(notification)
    
    await db.commit()
    return len(caregivers)


@router.patch("/{dose_log_id}", response_model=DoseLogResponse)
async def update_dose_status(
    dose_log_id: int,
    body: DoseLogStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Doz durumunu günceller (State Machine).

    İzinli geçişler:
      Bekliyor  → Alındı | Atlandı | Ertelendi
      Ertelendi → Alındı | Atlandı

    Alındı/Atlandı terminal durumlardır; bir kez girilince değiştirilemez.
    
    Modül 2 (Bildirim Sistemi):
        Durum "Atlandı"a geçildiğinde, ilgili bakıcılara otomatik bildirim
        gönderilir.

    Güvenlik: İlaç kaydının current_user'a ait olup olmadığı
    veritabanı sorgusuyla doğrulanır.
    """
    # Doz logu getir
    log_res = await db.execute(select(DoseLog).where(DoseLog.id == dose_log_id))
    log = log_res.scalar_one_or_none()
    if log is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doz logu bulunamadı.",
        )

    # Sahiplik kontrolü — başka kullanıcıların kayıtlarına erişimi engelle
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

    # State machine kontrolü
    allowed = _ALLOWED_TRANSITIONS.get(log.status, set())
    if body.status not in allowed:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"'{log.status}' durumundan '{body.status}' durumuna geçiş yapılamaz.",
        )

    # Güncelle
    # Davranış analizi: Ertelendi → terminal geçişinde was_postponed bayrağını koru.
    if log.status == "Ertelendi" and body.status in {"Alındı", "Atlandı"}:
        log.was_postponed = True
    log.status = body.status
    if body.notes is not None:
        log.notes = body.notes
    if body.status == "Alındı":
        log.actual_time = datetime.now()
    # Ertelendi: scheduled_time'i seçilen dk sonraya taşı — bildirim penceresi
    # otomatik olarak bu dozu belirtilen süre sonra tekrar yakalar (re-notification).
    # Varsayılan 15 dk (geriye dönük uyumluluk); /notifications/snooze endpoint'i
    # kullanıcı seçimine göre 5/10/15 dk gönderir.
    if body.status == "Ertelendi":
        snooze_minutes = 15  # PATCH üzerinden gelen eski istek uyumluluğu
        log.scheduled_time = datetime.now() + timedelta(minutes=snooze_minutes)
    
    # Modül 2: "Atlandı"a geçilirse bakıcılara bildirim gönder
    if body.status == "Atlandı":
        await _send_missed_dose_notification(db, current_user.id, log, medication)

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
