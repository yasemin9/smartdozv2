"""SmartDoz - Bildirim Router (EK1_revize.pdf Modül 2 & 7)

GET /notifications/pending
    Kullanıcıya ait, önümüzdeki WINDOW_MINUTES dakika içinde zamanı gelecek
    veya gecikmiş 'Bekliyor' / 'Ertelendi' doz loglarını döner.

Flutter frontend bu endpoint'i periyodik olarak polling yaparak
browser Notification API'si üzerinden bildirim gösterir.
Aynı doz için tekrar bildirim göndermemek frontend'in sorumluluğundadır
(_shownIds seti).
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import DoseLog, Medication, User
from schemas import DoseLogResponse

router = APIRouter(prefix="/notifications", tags=["Bildirimler"])

# Bildirim penceresi: şimdiden kaç dakika ilerisine kadar
WINDOW_MINUTES = 15
# Geriye doğru tolerans: gecikmeli dozları yakalamak için
BACK_TOLERANCE_MINUTES = 5


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
