"""SmartDoz - Takvim Router

Günlük ve aylık doz takvimini sağlar.
Günlük istekte DoseLog yoksa ZAMANDILIMIHESAPLA ile otomatik oluşturur.
"""
import calendar as _calendar
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import DoseLog, Medication, User
from schemas import (
    DailyCalendarResponse,
    DailySummary,
    DoseLogResponse,
    MonthlyCalendarResponse,
)
from services.scheduler import create_daily_dose_logs

router = APIRouter(prefix="/calendar", tags=["Takvim"])


def _build_dose_response(log: DoseLog, med: Medication) -> DoseLogResponse:
    return DoseLogResponse(
        id=log.id,
        medication_id=log.medication_id,
        medication_name=med.name,
        dosage_form=med.dosage_form,
        scheduled_time=log.scheduled_time,
        actual_time=log.actual_time,
        status=log.status,
        notes=log.notes,
    )


@router.get("/daily/{date_str}", response_model=DailyCalendarResponse)
async def get_daily_calendar(
    date_str: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Belirtilen günün doz loglarını döner.
    Log yoksa ZAMANDILIMIHESAPLA ile otomatik oluşturur (lazy creation).
    """
    try:
        target = date.fromisoformat(date_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz tarih formatı. YYYY-MM-DD kullanın.",
        )

    # Kullanıcı ilaçlarını al
    meds_res = await db.execute(
        select(Medication).where(Medication.user_id == current_user.id)
    )
    medications = meds_res.scalars().all()
    if not medications:
        return DailyCalendarResponse(date=date_str, dose_logs=[])

    med_ids = [m.id for m in medications]
    med_map = {m.id: m for m in medications}

    start_dt = datetime.combine(target, datetime.min.time())
    end_dt   = datetime.combine(target, datetime.max.time())

    logs_res = await db.execute(
        select(DoseLog).where(
            DoseLog.medication_id.in_(med_ids),
            DoseLog.scheduled_time >= start_dt,
            DoseLog.scheduled_time <= end_dt,
        )
    )
    logs = logs_res.scalars().all()

    # Yoksa oluştur, sonra tekrar çek
    if not logs:
        await create_daily_dose_logs(target)
        logs_res = await db.execute(
            select(DoseLog).where(
                DoseLog.medication_id.in_(med_ids),
                DoseLog.scheduled_time >= start_dt,
                DoseLog.scheduled_time <= end_dt,
            )
        )
        logs = logs_res.scalars().all()

    dose_responses = [
        _build_dose_response(log, med_map[log.medication_id])
        for log in sorted(logs, key=lambda l: l.scheduled_time)
        if log.medication_id in med_map
    ]

    return DailyCalendarResponse(date=date_str, dose_logs=dose_responses)


@router.get("/monthly/{year}/{month}", response_model=MonthlyCalendarResponse)
async def get_monthly_calendar(
    year: int,
    month: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Belirtilen aya ait günlük uyum istatistiklerini döner."""
    if not (1 <= month <= 12):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ay 1-12 arasında olmalıdır.",
        )

    _, last_day = _calendar.monthrange(year, month)
    start_dt = datetime(year, month, 1, 0, 0, 0)
    end_dt   = datetime(year, month, last_day, 23, 59, 59)

    meds_res = await db.execute(
        select(Medication).where(Medication.user_id == current_user.id)
    )
    med_ids = [m.id for m in meds_res.scalars().all()]

    if not med_ids:
        return MonthlyCalendarResponse(year=year, month=month, summary={})

    logs_res = await db.execute(
        select(DoseLog).where(
            DoseLog.medication_id.in_(med_ids),
            DoseLog.scheduled_time >= start_dt,
            DoseLog.scheduled_time <= end_dt,
        )
    )
    logs = logs_res.scalars().all()

    # Günlük gruplama
    groups: dict[str, list[DoseLog]] = {}
    for log in logs:
        key = log.scheduled_time.strftime("%Y-%m-%d")
        groups.setdefault(key, []).append(log)

    summary: dict[str, DailySummary] = {}
    for day_key, day_logs in groups.items():
        taken     = sum(1 for l in day_logs if l.status == "Alındı")
        missed    = sum(1 for l in day_logs if l.status == "Atlandı")
        postponed = sum(1 for l in day_logs if l.status == "Ertelendi")
        pending   = sum(1 for l in day_logs if l.status == "Bekliyor")
        total     = len(day_logs)
        compliance = taken / total if total > 0 else 0.0

        summary[day_key] = DailySummary(
            date=day_key,
            total=total,
            taken=taken,
            missed=missed,
            postponed=postponed,
            pending=pending,
            compliance_rate=round(compliance, 3),
        )

    return MonthlyCalendarResponse(year=year, month=month, summary=summary)
