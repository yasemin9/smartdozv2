"""
SmartDoz - Modül 7: Analitik Router

Endpoint'ler:
    GET  /analytics/adherence                     — Son 30 günlük uyum özeti
    GET  /analytics/adherence/weekly-trend        — Haftalık trend noktaları
    GET  /analytics/adherence/{medication_id}     — Belirli ilaç için uyum
    GET  /analytics/behavioral-deviation         — Davranışsal sapma analizi
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import get_current_user
from database import get_db
from models import User
from schemas import AdherenceSummaryResponse, BehavioralDeviationResponse
from services.adherence_service import get_adherence_summary, get_behavioral_deviation

router = APIRouter(prefix="/analytics", tags=["Modül 7 — Analitik"])


@router.get(
    "/adherence",
    response_model=AdherenceSummaryResponse,
    summary="Son N günlük tedavi uyum özeti (MPR tabanlı)",
)
async def get_adherence(
    days: int = Query(default=30, ge=1, le=365, description="Analiz periyodu (gün)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının belirtilen gün sayısı için MPR skorunu ve haftalık trendi döner.

    - **days**: 1–365 arası (varsayılan 30)
    - Yanıtta `adherence_score` 0.0 (hiç alınmamış) – 1.0 (tam uyumlu) arasındadır.
    - `weekly_trend` dizisi kronolojik sıradadır.
    """
    summary = await get_adherence_summary(
        user_id=current_user.id,
        db=db,
        days=days,
    )
    return _to_response(summary)


@router.get(
    "/adherence/{medication_id}",
    response_model=AdherenceSummaryResponse,
    summary="Belirli bir ilaç için tedavi uyum özeti",
)
async def get_adherence_by_medication(
    medication_id: int,
    days: int = Query(default=30, ge=1, le=365),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Tek bir ilaç için uyum metriği.
    Kullanıcının sahip olmadığı ilaç_id'leri için boş özet döner.
    """
    summary = await get_adherence_summary(
        user_id=current_user.id,
        db=db,
        days=days,
        medication_id=medication_id,
    )
    return _to_response(summary)


# ──────────────────────────────────────────────────────
# Yardımcı dönüştürücü
# ──────────────────────────────────────────────────────

def _to_response(summary) -> AdherenceSummaryResponse:
    from schemas import WeeklyTrendPointResponse

    return AdherenceSummaryResponse(
        period_start=summary.period_start,
        period_end=summary.period_end,
        total_planned=summary.total_planned,
        total_taken=summary.total_taken,
        total_skipped=summary.total_skipped,
        total_postponed=summary.total_postponed,
        adherence_score=summary.adherence_score,
        weekly_trend=[
            WeeklyTrendPointResponse(
                week_label=pt.week_label,
                week_start=pt.week_start,
                planned=pt.planned,
                taken=pt.taken,
                skipped=pt.skipped,
                postponed=pt.postponed,
                adherence_score=pt.adherence_score,
            )
            for pt in summary.weekly_trend
        ],
    )


@router.get(
    "/behavioral-deviation",
    response_model=BehavioralDeviationResponse,
    summary="Davranışsal sapma: En çok doz kaçırılan saat/gün analizi",
)
async def get_deviation(
    days: int = Query(default=30, ge=1, le=365, description="Analiz periyodu (gün)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının atlanmış dozlarını saate ve haftanin gününe göre analiz eder.

    - ``missed_by_hour``: Saat dilimine göre kaçırılan doz sayıcısı (0–23)
    - ``missed_by_day``: Pazartesi–Pazar ekseninde kaçırılan doz sayısı
    - ``peak_miss_hour``: En fazla gözlemlenen kaçırılan saat
    - ``peak_miss_day``: En fazla gözlemlenen kaçırılan gün

    KVKK: Sadece user_id bazında anonimleştirilmiş zaman aralıkları döndürülür.
    """
    deviation = await get_behavioral_deviation(
        user_id=current_user.id,
        db=db,
        days=days,
    )
    from schemas import MissedHourSlot, MissedDaySlot
    return BehavioralDeviationResponse(
        period_days=deviation.period_days,
        total_skipped=deviation.total_skipped,
        missed_by_hour=[
            MissedHourSlot(hour=h.hour, missed_count=h.missed_count)
            for h in deviation.missed_by_hour
        ],
        missed_by_day=[
            MissedDaySlot(
                day_of_week=d.day_of_week,
                day_name=d.day_name,
                missed_count=d.missed_count,
            )
            for d in deviation.missed_by_day
        ],
        peak_miss_hour=deviation.peak_miss_hour,
        peak_miss_day=deviation.peak_miss_day,
    )
