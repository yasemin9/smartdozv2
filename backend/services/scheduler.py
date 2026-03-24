"""
SmartDoz - İlaç Zamanlama Servisi

Algoritma 1: ZAMANDILIMIHESAPLA  (EK1_revize.pdf, Sayfa 37)
─────────────────────────────────────────────────────────────
Kullanıcının uyanıklık penceresini doz sayısına bölerek optimum
bildirim zamanlarını üretir.

Arka Plan Görev Mimarisi (EK1_revize.pdf, Sayfa 27):
    APScheduler → AsyncIOScheduler
    Production'da bu görevler Celery + RabbitMQ worker'larına
    taşınabilir (exchange: 'dose_schedule').
"""
import logging
from datetime import date, datetime, time, timedelta
from typing import List

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
from sqlalchemy.dialects.postgresql import insert as pg_insert

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────
# Global Scheduler (Singleton)
# ──────────────────────────────────────────────────────────
scheduler = AsyncIOScheduler(timezone="Europe/Istanbul")


# ══════════════════════════════════════════════════════════
# ZAMANDILIMIHESAPLA  (EK1_revize.pdf s.37)
# ══════════════════════════════════════════════════════════
def zamandilimihesapla(
    wake_time: time,
    sleep_time: time,
    frequency_per_day: int,
    reference_date: date | None = None,
) -> List[datetime]:
    """
    Algoritma 1 — İlaç Hatırlatma Zamanlama Algoritması

    Parametreler:
        wake_time         : Kullanıcı uyanma saati (ör. time(8, 0))
        sleep_time        : Kullanıcı uyku  saati  (ör. time(22, 0))
        frequency_per_day : Günlük doz sayısı      (ör. 3)
        reference_date    : Hesaplanacak tarih      (varsayılan: bugün)

    Algoritma:
        1. Uyanıklık penceresini dakika cinsinden hesapla
        2. Pencereyi (frequency + 1) eşit dilime böl
        3. 1..frequency arası her dilim sınırını doz zamanı olarak al
        4. Son dozun uyku saatinden ≥ 30 dk önce olmasını zorla

    Dönüş:
        Optimum datetime nesnelerinin listesi
    """
    if frequency_per_day <= 0:
        return []

    ref = reference_date or date.today()
    wake_dt = datetime.combine(ref, wake_time)
    sleep_dt = datetime.combine(ref, sleep_time)

    # Gece yarısını geçen uyku saatini ertesi güne taşı
    if sleep_dt <= wake_dt:
        sleep_dt += timedelta(days=1)

    window_minutes = (sleep_dt - wake_dt).total_seconds() / 60

    if frequency_per_day == 1:
        # Tek doz: uyanmadan 1 saat sonra
        return [wake_dt + timedelta(hours=1)]

    # Pencereyi (frequency+1) dilime böl → iç sınırları al
    interval = window_minutes / (frequency_per_day + 1)
    latest_allowed = sleep_dt - timedelta(minutes=30)

    result: List[datetime] = []
    for i in range(1, frequency_per_day + 1):
        dose_dt = wake_dt + timedelta(minutes=interval * i)
        if dose_dt > latest_allowed:
            dose_dt = latest_allowed
        result.append(dose_dt)

    return result


def parse_frequency(usage_frequency: str) -> int:
    """Kullanım sıklığı metnini günlük doz sayısına çevirir."""
    mapping = {
        "günde 1":      1,
        "günde 2":      2,
        "günde 3":      3,
        "her 6":        4,
        "her 8":        3,
        "her 12":       2,
        "haftada":      0,   # Haftalık ilaçlar ayrı yönetilir
        "gerektiğinde": 0,   # Serbest kullanım → otomatik log yok
    }
    freq_lower = usage_frequency.lower()
    for key, val in mapping.items():
        if key in freq_lower:
            return val
    return 1  # Varsayılan: günde 1


# ──────────────────────────────────────────────────────────
# Zamanlayıcı Görevleri
# ──────────────────────────────────────────────────────────

async def create_dose_logs_for_medication(
    medication_id: int,
    db,
    target_date: date | None = None,
) -> int:
    """
    Yeni eklenen bir ilaç için belirlenen güne ait DoseLog'ları
    ZAMANDILIMIHESAPLA algoritmasıyla anlık oluşturur.

    Medications router tarafından POST /medications/ sonrası çağrılır.
    Dönüş: oluşturulan log sayısı
    """
    from models import DoseLog, Medication, UserPreference
    from datetime import time as time_type
    from sqlalchemy import select

    target = target_date or date.today()

    med_res = await db.execute(select(Medication).where(Medication.id == medication_id))
    med = med_res.scalar_one_or_none()
    if med is None:
        return 0

    pref_res = await db.execute(
        select(UserPreference).where(UserPreference.user_id == med.user_id)
    )
    pref     = pref_res.scalar_one_or_none()
    wake_t   = pref.wake_time  if pref else time_type(8, 0)
    sleep_t  = pref.sleep_time if pref else time_type(22, 0)

    freq = parse_frequency(med.usage_frequency)
    if freq == 0:
        return 0

    dose_times = zamandilimihesapla(wake_t, sleep_t, freq, target)
    created = 0
    for dt in dose_times:
        # ON CONFLICT DO NOTHING — UniqueConstraint(medication_id, scheduled_time)
        stmt = (
            pg_insert(DoseLog)
            .values(medication_id=med.id, scheduled_time=dt, status="Bekliyor")
            .on_conflict_do_nothing(constraint="uq_dose_log_med_time")
        )
        result = await db.execute(stmt)
        created += result.rowcount

    await db.commit()
    logger.info(f"[Anlık] Medication #{medication_id} için {created} DoseLog oluşturuldu.")
    return created


async def create_daily_dose_logs(target_date: date | None = None) -> None:
    """
    Belirtilen tarih için tüm aktif ilaç kayıtlarına DoseLog oluşturur.

    RabbitMQ Notu (EK1_revize.pdf s.27):
        Bu fonksiyon bir RabbitMQ consumer tarafından
        'dose_schedule' exchange'i üzerinden tetiklenebilir.
    """
    from database import AsyncSessionLocal
    from models import DoseLog, Medication, UserPreference
    from datetime import time as time_type
    from sqlalchemy import select

    target = target_date or date.today()

    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(select(Medication))
            medications = result.scalars().all()

            created = 0
            for med in medications:
                pref_res = await db.execute(
                    select(UserPreference).where(UserPreference.user_id == med.user_id)
                )
                pref = pref_res.scalar_one_or_none()
                wake_t  = pref.wake_time  if pref else time_type(8, 0)
                sleep_t = pref.sleep_time if pref else time_type(22, 0)

                freq = parse_frequency(med.usage_frequency)
                if freq == 0:
                    continue

                dose_times = zamandilimihesapla(wake_t, sleep_t, freq, target)
                for dt in dose_times:
                    stmt = (
                        pg_insert(DoseLog)
                        .values(medication_id=med.id, scheduled_time=dt, status="Bekliyor")
                        .on_conflict_do_nothing(constraint="uq_dose_log_med_time")
                    )
                    result2 = await db.execute(stmt)
                    created += result2.rowcount

            await db.commit()
            logger.info(f"[Scheduler] {target} için {created} yeni DoseLog oluşturuldu.")
        except Exception as exc:
            await db.rollback()
            logger.error(f"[Scheduler] create_daily_dose_logs hatası: {exc}")


async def mark_missed_doses() -> None:
    """
    Zamanı 30+ dakika geçmiş ve hâlâ 'Bekliyor' olan dozları
    otomatik olarak 'Atlandı' olarak işaretler.
    """
    from database import AsyncSessionLocal
    from models import DoseLog
    from sqlalchemy import select

    grace_cutoff = datetime.now() - timedelta(minutes=30)

    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(
                select(DoseLog).where(
                    DoseLog.status == "Bekliyor",
                    DoseLog.scheduled_time < grace_cutoff,
                )
            )
            missed = result.scalars().all()
            for log in missed:
                log.status = "Atlandı"
            if missed:
                await db.commit()
                logger.info(f"[Scheduler] {len(missed)} doz 'Atlandı' olarak güncellendi.")
        except Exception as exc:
            await db.rollback()
            logger.error(f"[Scheduler] mark_missed_doses hatası: {exc}")


# ──────────────────────────────────────────────────────────
# Scheduler Kurulum
# ──────────────────────────────────────────────────────────

def setup_scheduler() -> AsyncIOScheduler:
    """
    APScheduler görevlerini tanımlar ve scheduler'ı döner.

    Görev Planı:
        00:01  — Yeni günün doz loglarını oluştur (cron)
        10 dk  — Gecikmiş dozları 'Atlandı' yap  (interval)
    """
    # Her gece 00:01'de günlük logları oluştur
    scheduler.add_job(
        create_daily_dose_logs,
        CronTrigger(hour=0, minute=1, timezone="Europe/Istanbul"),
        id="daily_dose_logs",
        replace_existing=True,
        misfire_grace_time=300,
    )

    # Her 10 dakikada bir gecikmiş dozları kontrol et
    scheduler.add_job(
        mark_missed_doses,
        IntervalTrigger(minutes=10),
        id="check_missed_doses",
        replace_existing=True,
    )

    return scheduler
