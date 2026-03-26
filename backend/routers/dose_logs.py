"""SmartDoz - Doz Takip Router

PATCH /dose-logs/{id}  — Doz durumunu günceller.
Yalnızca kaydın sahibi bu endpoint'i kullanabilir.

State Machine (EK1_revize.pdf s.44 — MPR & Uyum):
    Bekliyor  → Alındı | Atlandı | Ertelendi
    Ertelendi → Alındı | Atlandı          (esnek geri dönüş)
    Alındı    → (terminal — değiştirilemez)
    Atlandı   → (terminal — değiştirilemez)
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import DoseLog, Medication, User
from schemas import DoseLogResponse, DoseLogStatusUpdate

router = APIRouter(prefix="/dose-logs", tags=["Doz Takip"])

# Hangi durumdan hangi durumlara geçiş izni var
_ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "Bekliyor":  {"Alındı", "Atlandı", "Ertelendi"},
    "Ertelendi": {"Alındı", "Atlandı"},
    "Alındı":    set(),   # terminal
    "Atlandı":   set(),   # terminal
}


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
    # Ertelendi: scheduled_time'i 15 dakika sonraya taşı — bildirim penceresi
    # otomatik olarak bu dozu 15 dk sonra tekrar yakalar (re-notification).
    # Not: bu bir UPDATE'dir; UniqueConstraint sadece INSERT'te tetiklenir.
    if body.status == "Ertelendi":
        log.scheduled_time = datetime.now() + timedelta(minutes=15)

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
