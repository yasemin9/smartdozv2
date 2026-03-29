"""
SmartDoz - Modül 7: Tedavi Uyumu Hesaplama Servisi

Algoritma 4: MPR (Medication Possession Ratio) tabanlı uyum skorlama.
    Uyum Skoru = Alınan Doz Sayısı / Planlanan Toplam Doz Sayısı
    Skor aralığı: 0.0 – 1.0

Haftalık trend analizi için Pandas DataFrame kullanılır.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

import pandas as pd
import pytz
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import DoseLog, Medication

logger = logging.getLogger(__name__)

# Uygulama gençlinde Istanbul yerel saatinin referans zaman dilimi.
# Döz zamanları naive Istanbul local datetime olarak saklanır;
# sorgu pencereleri de aynı zaman dilimiyle üretilmelidir.
_ISTANBUL_TZ = pytz.timezone("Europe/Istanbul")


def _now_istanbul() -> datetime:
    """Anlık Istanbul yerel saatini timezone-naive olarak döner."""
    return datetime.now(_ISTANBUL_TZ).replace(tzinfo=None)


# ──────────────────────────────────────────────────────
# Veri Transfer Nesneleri (saf Python dataclass'ları —
# FastAPI serileştirmesi için schemas.py'deki Pydantic
# modellerine dönüştürülür)
# ──────────────────────────────────────────────────────

from dataclasses import dataclass, field


@dataclass
class WeeklyTrendPoint:
    """Bir haftaya ait uyum verisi."""
    week_label: str          # ISO hafta etiketi, ör. "2025-W05"
    week_start: str          # ISO 8601 tarih, ör. "2025-01-27"
    planned: int
    taken: int
    skipped: int
    postponed: int
    adherence_score: float   # 0.0 – 1.0


@dataclass
class AdherenceSummary:
    """Son 30 günlük genel uyum özeti."""
    period_start: str
    period_end: str
    total_planned: int
    total_taken: int
    total_skipped: int
    total_postponed: int
    adherence_score: float   # 0.0 – 1.0
    weekly_trend: list[WeeklyTrendPoint] = field(default_factory=list)


# ──────────────────────────────────────────────────────
# Çekirdek Hesaplama Fonksiyonları
# ──────────────────────────────────────────────────────

def _calculate_mpr(taken: int, planned: int) -> float:
    """
    MPR = Alınan / Planlanan.

    Sıfıra bölme hatası engellenmiştir; planlanan doz yoksa
    anlamlı bir oran hesaplanamaz → 0.0 döner.
    """
    if planned == 0:
        return 0.0
    return round(min(taken / planned, 1.0), 4)


def _daily_trend_from_dataframe(
    df: pd.DataFrame,
    period_start: datetime,
    period_end: datetime,
) -> list[WeeklyTrendPoint]:
    """
    DoseLog kayıtlarından oluşan DataFrame'i alır ve günlük olarak gruplar.

    Veri olmayan günler için bir önceki günün skoru (forward-fill) uygulanır;
    böylece grafik 0%'a düşmez. Hiç veri yoksa liste boş döner.

    Beklenen sütunlar:
        scheduled_time (datetime), status (str)
    """
    from datetime import date as _date

    start_d = period_start.date()
    end_d   = period_end.date()
    all_days = [start_d + timedelta(days=i) for i in range((end_d - start_d).days + 1)]

    if df.empty:
        return []

    df = df.copy()
    df["scheduled_time"] = pd.to_datetime(df["scheduled_time"])
    df["day"] = df["scheduled_time"].dt.date

    # Günlük gruplama: her güne ait Alındı / Atlandı / Ertelendi sayımı
    daily_map: dict = {}
    for day, group in df.groupby("day", sort=True):
        taken     = int((group["status"] == "Alındı").sum())
        skipped   = int((group["status"] == "Atlandı").sum())
        postponed = int(group["was_postponed"].sum()) if "was_postponed" in group.columns else 0
        planned   = taken + skipped
        score     = _calculate_mpr(taken, planned)
        daily_map[day] = {
            "taken": taken,
            "skipped": skipped,
            "postponed": postponed,
            "planned": planned,
            "score": score,
        }

    trend_points: list[WeeklyTrendPoint] = []
    last_score: float | None = None

    for d in all_days:
        if d in daily_map:
            data = daily_map[d]
            last_score = data["score"]
            trend_points.append(
                WeeklyTrendPoint(
                    week_label=d.strftime("%d/%m"),
                    week_start=str(d),
                    planned=data["planned"],
                    taken=data["taken"],
                    skipped=data["skipped"],
                    postponed=data["postponed"],
                    adherence_score=data["score"],
                )
            )
        elif last_score is not None:
            # Veri yok: forward-fill — bir önceki günün skoru
            trend_points.append(
                WeeklyTrendPoint(
                    week_label=d.strftime("%d/%m"),
                    week_start=str(d),
                    planned=0,
                    taken=0,
                    skipped=0,
                    postponed=0,
                    adherence_score=last_score,
                )
            )
        # last_score None ise (başlangıçta veri yoksa) o günü atla

    return trend_points


# ──────────────────────────────────────────────────────
# Asenkron Servis Fonksiyonları
# ──────────────────────────────────────────────────────

async def get_adherence_summary(
    user_id: int,
    db: AsyncSession,
    days: int = 30,
    medication_id: Optional[int] = None,
) -> AdherenceSummary:
    """
    Kullanıcının son ``days`` günlük tedavi uyum özetini hesaplar.

    Args:
        user_id:       Kimlik doğrulanmış kullanıcının ID'si.
        db:            Aktif asenkron veritabanı oturumu.
        days:          Analiz periyodu (varsayılan 30 gün).
        medication_id: Belirli bir ilaç için filtrele (opsiyonel).

    Returns:
        Haftalık trend içeren AdherenceSummary nesnesi.
    """
    # Döz zamanları naive Istanbul local datetime olarak kaydedilir;
    # sorgu penceresi de Istanbul yerel saati kullanılarak üretilir.
    now          = _now_istanbul()
    today_start  = now.replace(hour=0, minute=0, second=0, microsecond=0)
    # period_end: bugünün SONU (yarının 00:00) — saati henüz gelmemiş
    # ama daha önceden 'Alındı' işaretlenmiş bugünkü dozlar da dahil edilir.
    period_end   = today_start + timedelta(days=1)
    period_start = today_start - timedelta(days=days - 1)

    # Temel sorgu: kullanıcının ilacına ait loglar
    query = (
        select(DoseLog)
        .join(Medication, DoseLog.medication_id == Medication.id)
        .where(
            Medication.user_id == user_id,
            DoseLog.scheduled_time >= period_start,
            DoseLog.scheduled_time <= period_end,
        )
    )

    if medication_id is not None:
        query = query.where(DoseLog.medication_id == medication_id)

    result = await db.execute(query)
    logs = result.scalars().all()

    if not logs:
        return AdherenceSummary(
            period_start=period_start.date().isoformat(),
            period_end=today_start.date().isoformat(),
            total_planned=0,
            total_taken=0,
            total_skipped=0,
            total_postponed=0,
            adherence_score=0.0,
            weekly_trend=[],
        )

    # Pandas DataFrame oluştur
    records = [
        {
            "id": log.id,
            "medication_id": log.medication_id,
            "scheduled_time": log.scheduled_time,
            "status": log.status,
            # was_postponed: Ertelendi→Alındı gibi köprü geçişlerde bile True kalır
            "was_postponed": getattr(log, "was_postponed", False),
        }
        for log in logs
    ]
    df = pd.DataFrame(records)

    # Algoritma 4: MPR = N_alınan / N_planlanan
    # N_planlanan = sadece terminal (Alındı + Atlandı) dozlar
    # Ertelendi/Bekliyor = henüz tamamlanmamış — MPR paydasına dahil edilmez
    taken_count     = int((df["status"] == "Alındı").sum())
    skipped_count   = int((df["status"] == "Atlandı").sum())
    planned_count   = taken_count + skipped_count
    # was_postponed: son durum Alındı bile olsa erteleme sayılır (Madde 3)
    postponed_count = int(df["was_postponed"].sum())

    adherence_score = _calculate_mpr(taken_count, planned_count)

    weekly_trend = _daily_trend_from_dataframe(df, period_start, period_end)

    logger.info(
        "Uyum hesaplandı: user_id=%s, days=%s, score=%.4f",
        user_id, days, adherence_score,
    )

    return AdherenceSummary(
        period_start=period_start.date().isoformat(),
        period_end=today_start.date().isoformat(),
        total_planned=planned_count,
        total_taken=taken_count,
        total_skipped=skipped_count,
        total_postponed=postponed_count,
        adherence_score=adherence_score,
        weekly_trend=weekly_trend,
    )


async def record_dose_action(
    dose_log_id: int,
    status: str,
    actual_time: datetime,
    notes: Optional[str],
    user_id: int,
    db: AsyncSession,
) -> DoseLog:
    """
    Kullanıcı bir doz eylemi gerçekleştirdiğinde (Alındı / Atlandı / Ertelendi)
    DoseLog kaydını ISO 8601 zaman damgasıyla günceller.

    Bu fonksiyon yalnızca validasyon sonrası çağrılmalıdır;
    state machine kontrolü router katmanında yapılır.
    """
    result = await db.execute(
        select(DoseLog)
        .join(Medication, DoseLog.medication_id == Medication.id)
        .where(
            DoseLog.id == dose_log_id,
            Medication.user_id == user_id,
        )
    )
    log = result.scalar_one_or_none()
    if log is None:
        raise ValueError(f"DoseLog id={dose_log_id} bulunamadı veya erişim izni yok.")

    log.status = status
    log.actual_time = actual_time
    if notes is not None:
        log.notes = notes

    await db.commit()
    await db.refresh(log)
    return log


# ──────────────────────────────────────────────────────
# Modül 7: Davranışsal Sapma Analizi
# ──────────────────────────────────────────────────────

_TR_DAY_NAMES = [
    "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"
]


@dataclass
class MissedHourSlot:
    hour: int
    missed_count: int


@dataclass
class MissedDaySlot:
    day_of_week: int
    day_name: str
    missed_count: int


@dataclass
class BehavioralDeviation:
    period_days: int
    total_skipped: int
    missed_by_hour: list[MissedHourSlot]
    missed_by_day: list[MissedDaySlot]
    peak_miss_hour: Optional[int]
    peak_miss_day: Optional[str]


async def get_behavioral_deviation(
    user_id: int,
    db: AsyncSession,
    days: int = 30,
) -> BehavioralDeviation:
    """
    Kullanıcının son ``days`` günlük atlanmış dozlarını saate ve haftanın
    gününe göre gruplar; en çok kaçırılan zaman dilimlerini tespit eder.

    KVKK uyumluluğu: Yalnızca user_id üzerinden filtreleme yapılır;
    bireysel doz içerikleri dışa açılmaz.
    """
    now          = _now_istanbul()
    today_start  = now.replace(hour=0, minute=0, second=0, microsecond=0)
    period_end   = today_start + timedelta(days=1)  # bugünün sonu
    period_start = today_start - timedelta(days=days - 1)

    query = (
        select(DoseLog.scheduled_time)
        .join(Medication, DoseLog.medication_id == Medication.id)
        .where(
            Medication.user_id == user_id,
            DoseLog.status == "Atlandı",
            DoseLog.scheduled_time >= period_start,
            DoseLog.scheduled_time < period_end,
        )
    )
    result = await db.execute(query)
    missed_times = result.scalars().all()

    if not missed_times:
        return BehavioralDeviation(
            period_days=days,
            total_skipped=0,
            missed_by_hour=[],
            missed_by_day=[],
            peak_miss_hour=None,
            peak_miss_day=None,
        )

    df = pd.DataFrame({"scheduled_time": pd.to_datetime(missed_times)})
    df["hour"]        = df["scheduled_time"].dt.hour
    df["day_of_week"] = df["scheduled_time"].dt.dayofweek  # 0=Monday

    # Saate göre dağılım — tüm 0-23 saatleri temsil et
    hour_counts = df["hour"].value_counts().sort_index()
    missed_by_hour: list[MissedHourSlot] = [
        MissedHourSlot(hour=h, missed_count=int(hour_counts.get(h, 0)))
        for h in range(24)
        if int(hour_counts.get(h, 0)) > 0
    ]
    missed_by_hour.sort(key=lambda x: x.missed_count, reverse=True)

    # Güne göre dağılım
    day_counts = df["day_of_week"].value_counts().sort_index()
    missed_by_day: list[MissedDaySlot] = [
        MissedDaySlot(
            day_of_week=d,
            day_name=_TR_DAY_NAMES[d],
            missed_count=int(day_counts.get(d, 0)),
        )
        for d in range(7)
        if int(day_counts.get(d, 0)) > 0
    ]
    missed_by_day.sort(key=lambda x: x.missed_count, reverse=True)

    peak_hour = missed_by_hour[0].hour if missed_by_hour else None
    peak_day  = missed_by_day[0].day_name if missed_by_day else None

    logger.info(
        "Davranışsal sapma: user_id=%s, days=%s, total_skipped=%s, peak_hour=%s, peak_day=%s",
        user_id, days, len(missed_times), peak_hour, peak_day,
    )

    return BehavioralDeviation(
        period_days=days,
        total_skipped=len(missed_times),
        missed_by_hour=missed_by_hour,
        missed_by_day=missed_by_day,
        peak_miss_hour=peak_hour,
        peak_miss_day=peak_day,
    )
