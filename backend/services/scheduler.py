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


def parse_interval_hours(usage_frequency: str) -> int | None:
    """
    Saatlik aralık tabanlı sıklıktan saat değerini çıkarır.
    'Her 8 saatte bir' → 8, 'Her 12 saatte bir' → 12, diğerleri → None
    """
    freq_lower = usage_frequency.lower()
    if "her" in freq_lower and "saat" in freq_lower:
        import re as _re
        m = _re.search(r"\b(\d+)\b", freq_lower)
        if m:
            h = int(m.group(1))
            if h > 0 and 24 % h == 0:
                return h
    return None


# ──────────────────────────────────────────────────────────
# Rutin → Saat Çözümleyici  (Modül 2 — Kişiye Özel Hatırlatıcı)
# ──────────────────────────────────────────────────────────

# Rutin bağımlı kullanım zamanları ve offset'leri (dakika)
_ROUTINE_MAP: dict[str, tuple[str, int]] = {
    # usage_time metni        → (pref alanı       , offset_dk)
    "sabah":                   ("breakfast_time",   0),
    "kahvaltıdan önce":        ("breakfast_time", -30),
    "kahvaltıdan sonra":       ("breakfast_time",  30),
    "öğle":                    ("lunch_time",       0),
    "öğleden önce":            ("lunch_time",      -30),
    "öğleden sonra":           ("lunch_time",       30),
    "akşam":                   ("dinner_time",      0),
    "akşam yemeğinden önce":   ("dinner_time",     -30),
    "akşam yemeğinden sonra":  ("dinner_time",      30),
    "yemekten önce":           ("dinner_time",     -30),   # genel → akşam yemeğine bağla
    "yemekten sonra":          ("dinner_time",      30),   # genel → akşam yemeğine bağla
    "yatmadan önce":           ("bedtime",         -15),
    "aç karnına":              ("breakfast_time",  -30),
}

# Varsayılan saat: rutin tanımlanmamış ise kullanılan saatler
_ROUTINE_DEFAULTS: dict[str, time] = {
    "breakfast_time": time(8, 0),
    "lunch_time":     time(13, 0),
    "dinner_time":    time(19, 0),
    "bedtime":        time(22, 0),
}


def resolve_usage_time_from_routine(
    usage_time: str,
    pref,                    # UserPreference ORM nesnesi veya None
    target_date: date,
) -> datetime | None:
    """
    Kategorik kullanım zamanını (örn. 'Sabah', 'Yemekten sonra') kullanıcının
    profil rutinine göre gerçek bir datetime'a çevirir.

    Rutin açık ise → rutin_saati + offset
    Rutin None ise  → ROUTINE_DEFAULTS saati + offset (güvenli varsayılan)
    Aralıklı sıklık veya tanımsız format → None (çağıran zamandilimihesapla kullanır)
    """
    key = usage_time.strip().lower()
    if key not in _ROUTINE_MAP:
        return None

    pref_field, offset_min = _ROUTINE_MAP[key]
    # Kullanıcı bu rutini tanımlamış mı?
    routine_time: time | None = getattr(pref, pref_field, None) if pref else None
    if routine_time is None:
        routine_time = _ROUTINE_DEFAULTS[pref_field]
        logger.debug(
            f"[resolve] '{usage_time}' için rutin bulunamadı, "
            f"varsayılan {routine_time} kullanılıyor."
        )

    base_dt = datetime.combine(target_date, routine_time)
    result_dt = base_dt + timedelta(minutes=offset_min)
    return result_dt


def _parse_hhmm(s: str) -> time | None:
    """'HH:MM' metnini time nesnesine çevirir; hatalı formatta None döner."""
    try:
        h, m = map(int, s.strip().split(":"))
        if 0 <= h <= 23 and 0 <= m <= 59:
            return time(h, m)
    except (ValueError, AttributeError):
        pass
    return None


def parse_multislot_usage_time(
    usage_time: str,
    target_date: date,
    pref,
) -> list[datetime] | None:
    """
    Flutter'dan gelen çok-doz zaman formatını ayrıştırır:
        'Sabah|09:00;Akşam|20:00'
        'Öğle|13:00|Yemekten sonra;Akşam|19:30'

    Her slot için kullanıcının seçtiği HH:MM saatini kullanır.
    HH:MM geçersizse rutin tabanlı çözümlemeye düşer.

    Eğer format tanınmazsa None döner (eski tek-etiket akışına geçilir).
    """
    if ";" not in usage_time and "|" not in usage_time:
        return None   # Eski format

    result: list[datetime] = []
    for part in usage_time.split(";"):
        tokens = [t.strip() for t in part.split("|")]
        if len(tokens) < 2:
            continue
        t = _parse_hhmm(tokens[1])
        if t is None:
            # HH:MM geçersizse rutin tabanlı hesapla
            routine_dt = resolve_usage_time_from_routine(tokens[0], pref, target_date)
            if routine_dt:
                result.append(routine_dt)
        else:
            result.append(datetime.combine(target_date, t))

    return result if result else None


def calculate_interval_doses(
    first_dose_str: str,
    interval_hours: int,
    target_date: date,
) -> list[datetime]:
    """
    Algoritma 1 Uzantısı — İlk Doz Saatinden Aralıklı Doz Hesaplaması

    İlk dozdan başlayarak X saatlik aralıklarla gündüzlü dozları üretir.
    Gün bazlı çakışmaları önlemek için sadece hedef tarihe düşen
    zaman dilimlerini döndürür.

    Parametreler:
        first_dose_str  : 'HH:MM' formatında ilk doz saati
        interval_hours  : Doz aralığı (saat cinsinden, ör: 8)
        target_date     : Hedef tarih

    Dönüş:
        Hedef güne ait datetime nesnelerinin listesi
    """
    try:
        h, m = map(int, first_dose_str.strip().split(":"))
        if not (0 <= h <= 23 and 0 <= m <= 59):
            raise ValueError("Geçersiz saat değeri")
    except (ValueError, AttributeError):
        logger.warning(
            f"Geçersiz ilk doz formatı: {first_dose_str!r}. Varsayılan 08:00 kullanılıyor."
        )
        h, m = 8, 0

    first_dose_dt = datetime.combine(target_date, time(h, m))
    count = 24 // interval_hours
    return [
        first_dose_dt + timedelta(hours=interval_hours * i)
        for i in range(count)
    ]


async def generate_schedule_for_medication_on_date(
    med,
    db,
    target_date: date,
) -> List[datetime]:
    """Tek bir ilacın belirli gün doz saatlerini üretir.

    Öncelik sırası:
    1. Aralık tabanlı sıklık (Her 8/12 saatte bir): matematiksel hesaplama
    2. Çok-doz slot formatı ('Sabah|09:00;Akşam|20:00'): doğrudan saatler
    3. Tek etiket ('Sabah'): rutin tabanlı çözümleme
    4. Fallback: ZAMANDILIMIHESAPLA
    """
    # ── Aralık tabanlı sıklık — Algoritma 1 Uzantısı
    interval_hours = parse_interval_hours(med.usage_frequency)
    if interval_hours is not None:
        return calculate_interval_doses(med.usage_time, interval_hours, target_date)

    # ── Ortak: kullanıcı tercihlerini yükle
    from datetime import time as time_type
    from models import UserPreference
    from sqlalchemy import select

    pref_res = await db.execute(
        select(UserPreference).where(UserPreference.user_id == med.user_id)
    )
    pref = pref_res.scalar_one_or_none()

    # ── Çok-doz slot formatı ('Sabah|09:00;Akşam|20:00')
    multislot = parse_multislot_usage_time(med.usage_time, target_date, pref)
    if multislot is not None:
        return sorted(multislot)

    # ── Tek etiket: rutin tabanlı çözümleme
    routine_dt = resolve_usage_time_from_routine(med.usage_time, pref, target_date)
    if routine_dt is not None:
        return [routine_dt]

    # Rutin eşleşmesi yoksa → ZAMANDILIMIHESAPLA
    wake_t  = pref.wake_time  if pref else time_type(8, 0)
    sleep_t = pref.sleep_time if pref else time_type(22, 0)

    freq = parse_frequency(med.usage_frequency)
    if freq == 0:
        return []

    return zamandilimihesapla(wake_t, sleep_t, freq, target_date)


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
    from models import DoseLog, Medication
    from sqlalchemy import select

    target = target_date or date.today()

    med_res = await db.execute(select(Medication).where(Medication.id == medication_id))
    med = med_res.scalar_one_or_none()
    if med is None:
        return 0

    dose_times = await generate_schedule_for_medication_on_date(med, db, target)
    if not dose_times:
        return 0
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


async def create_future_dose_logs_for_medication(
    medication_id: int,
    db,
    days: int = 30,
) -> int:
    """
    Yeni ilaç eklendiğinde gelecek N günün planlanan dozlarını DB'ye yazar.
    MPR ve takvim sorguları için veri tabanı doluluğunu garanti eder.
    """
    from models import DoseLog, Medication
    from sqlalchemy import select

    med_res = await db.execute(select(Medication).where(Medication.id == medication_id))
    med = med_res.scalar_one_or_none()
    if med is None:
        return 0

    created_total = 0
    today = date.today()
    for day_offset in range(days):
        target = today + timedelta(days=day_offset)
        dose_times = await generate_schedule_for_medication_on_date(med, db, target)
        for dt in dose_times:
            stmt = (
                pg_insert(DoseLog)
                .values(medication_id=med.id, scheduled_time=dt, status="Bekliyor")
                .on_conflict_do_nothing(constraint="uq_dose_log_med_time")
            )
            result = await db.execute(stmt)
            created_total += result.rowcount

    await db.commit()
    logger.info(
        f"[Seed] Medication #{medication_id} için {days} günlük pencerede "
        f"{created_total} DoseLog hazırlandı."
    )
    return created_total


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
                dose_times = await generate_schedule_for_medication_on_date(med, db, target)
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
