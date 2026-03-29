"""
SmartDoz - Modül 8: YZ Destekli Karar Motoru (Decision Engine)

Algoritma 5: KARAR_MOTORU
──────────────────────────────────────────────────────────────────────────────
Üç Katmanlı Yapı:

  1. Davranışsal Örüntü Analizi Katmanı
     - Son 30 günlük doz loglarını sabah/öğle/akşam pencerelerine böler
     - Her pencere için Lokal Uyum Skoru (S_local) hesaplar
     - Ardışık 3+ atlama → "Sistematik Davranışsal Sapma"

  2. Kural Tabanlı Karar Mekanizması
     - Klinik risk (YUKSEK etkileşim) → DOCTOR_REFERRAL, saat DEĞİŞTİRME
     - Sistematik sapma + ortalama gecikme > 15 dk → SCHEDULE_SHIFT (±15–30 dk)
     - Uyum skoru > 0.9 → TONE_ADAPT (yumuşak alarm)
     - Uyum skoru < 0.5 → TONE_ADAPT (dikkat çekici alarm)
     - Başarısız müdahale → GAMIFICATION

  3. Kapalı Döngü Geri Bildirim
     - Onaylanan kararlar 7 gün boyunca takip edilir
     - Uyum iyileşmesi > %10 → outcome = SUCCESS
     - Aksi hâlde → outcome = FAILURE; GAMIFICATION tetiklenir

Güvenlik Garantileri:
  - Klinik risk varsa saat asla değiştirilmez
  - Kullanıcı onaylamadan hiçbir değişiklik uygulanmaz
  - Aktif PENDING karar varken aynı pencere için yeni karar üretilmez
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional

import pytz
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import AIDecision, DoseLog, Medication

logger = logging.getLogger(__name__)

_ISTANBUL_TZ = pytz.timezone("Europe/Istanbul")

# ──────────────────────────────────────────────────────
# Zaman Penceresi Sabitleri
# ──────────────────────────────────────────────────────
_MORNING_START = 6
_MORNING_END   = 12
_NOON_START    = 12
_NOON_END      = 18
# Akşam: 18:00–06:00 arası (gece dahil)

_WINDOW_LABELS = {
    "morning": "Sabah",
    "noon":    "Öğle",
    "evening": "Akşam",
}

# Ardışık aylama eşiği
_CONSECUTIVE_SKIP_THRESHOLD = 2
# Müdahale tetikleyen gecikme (dk)
_DELAY_TRIGGER_MINUTES = 15
# Maksimum saat kaydırma (dk)
_MAX_SHIFT_MINUTES = 30
# Kapalı döngü takip süresi (gün)
_TRACKING_DAYS = 7
# Kararın geçerlilik süresi (saat)
_DECISION_EXPIRY_HOURS = 48
# Uyum: yüksek eşik (ton adaptasyonu — yumuşat)
_HIGH_ADHERENCE = 0.90
# Uyum: düşük eşik (ton adaptasyonu — sert)
_LOW_ADHERENCE  = 0.50
# Pencere başarısızlık eşiği
_WINDOW_FAILURE_THRESHOLD = 0.60


def _now_istanbul() -> datetime:
    return datetime.now(_ISTANBUL_TZ).replace(tzinfo=None)


def _classify_window(hour: int) -> str:
    """Saat değerinden zaman penceresi döner."""
    if _MORNING_START <= hour < _MORNING_END:
        return "morning"
    if _NOON_START <= hour < _NOON_END:
        return "noon"
    return "evening"


def _reason_counts(logs: list[DoseLog]) -> dict[str, int]:
    """
    Atlanmış dozların ``notes`` (kullanıcı sebep) alanını sayar.

    Dönen sözlük: {"Unuttum": 3, "Uyuyordum": 2, ...}
    """
    counts: dict[str, int] = {}
    for log in logs:
        if log.status == "Atlandı" and log.notes:
            reason = log.notes.strip()
            if reason:
                counts[reason] = counts.get(reason, 0) + 1
    return counts


def _dominant_reason(logs: list[DoseLog]) -> Optional[str]:
    """Atlanmış dozlar arasında en sık tekrar eden sebebi döner."""
    counts = _reason_counts(logs)
    return max(counts, key=counts.__getitem__) if counts else None


# ──────────────────────────────────────────────────────
# Veri Transfer Nesneleri
# ──────────────────────────────────────────────────────

@dataclass
class WindowAnalysis:
    """Bir zaman penceresi için analiz sonucu."""
    window: str
    label: str
    planned: int
    taken: int
    local_score: float
    consecutive_skips: int
    avg_delay_minutes: float   # Alınan dozlardaki ortalama gecikme (dakika)
    has_systematic_deviation: bool


@dataclass
class BehaviorProfileResult:
    """Kullanıcı davranış profili analiz sonucu."""
    profile_type: str
    profile_icon: str
    description: str
    overall_score: float
    window_analyses: list[WindowAnalysis] = field(default_factory=list)


@dataclass
class DecisionResult:
    """Oluşturulan karar nesnesi (DB'ye yazılmadan önce)."""
    decision_type: str
    time_window: Optional[str]
    explanation: str
    payload: dict
    medication_id: Optional[int] = None


# ──────────────────────────────────────────────────────
# Çekirdek Analiz Fonksiyonları
# ──────────────────────────────────────────────────────

def _analyze_window(logs: list[DoseLog], window: str) -> WindowAnalysis:
    """
    Verilen penceredeki logları analiz eder.

    Args:
        logs:   Sadece bu pencereye ait doz logları (sorted by scheduled_time).
        window: "morning" | "noon" | "evening"

    Returns:
        WindowAnalysis nesnesi.
    """
    label   = _WINDOW_LABELS[window]
    taken   = sum(1 for l in logs if l.status == "Alındı")
    skipped = sum(1 for l in logs if l.status == "Atlandı")
    planned = taken + skipped

    local_score = round(taken / planned, 4) if planned > 0 else 0.0

    # Ardışık atlama sayısı (sona doğru, en son ardışıklık)
    consecutive_skips = 0
    max_streak        = 0
    for log in sorted(logs, key=lambda l: l.scheduled_time):
        if log.status == "Atlandı":
            consecutive_skips += 1
            max_streak = max(max_streak, consecutive_skips)
        else:
            consecutive_skips = 0

    # Ortalama gecikme: sadece "Alındı" olan ve actual_time farklı dozlar
    delays = []
    for log in logs:
        if log.status == "Alındı" and log.actual_time and log.scheduled_time:
            delta = (log.actual_time - log.scheduled_time).total_seconds() / 60
            # Yalnızca pozitif gecikmeler (önceden alım hariç)
            if delta > 0:
                delays.append(delta)

    avg_delay = round(sum(delays) / len(delays), 1) if delays else 0.0
    has_deviation = max_streak >= _CONSECUTIVE_SKIP_THRESHOLD

    return WindowAnalysis(
        window=window,
        label=label,
        planned=planned,
        taken=taken,
        local_score=local_score,
        consecutive_skips=max_streak,
        avg_delay_minutes=avg_delay,
        has_systematic_deviation=has_deviation,
    )


def _build_behavior_profile(
    window_analyses: list[WindowAnalysis],
    overall_score: float,
) -> BehaviorProfileResult:
    """
    Pencere analizlerinden davranış profili üretir.

    Profil tipleri (öncelik sırasıyla):
        Sistematik Sapma  — herhangi bir pencerede ardışık 3+ atlama
        Düzenli Kullanıcı — overall_score >= 0.85
        Sabah Tipi        — sabah lokal skoru en yüksek
        Akşam Tipi        — akşam lokal skoru en yüksek
        Gelişiyor         — nötr durum
    """
    has_deviation = any(w.has_systematic_deviation for w in window_analyses)
    if has_deviation:
        worst = min(window_analyses, key=lambda w: w.local_score)
        return BehaviorProfileResult(
            profile_type="Sistematik Sapma",
            profile_icon="⚠️",
            description=(
                f"{worst.label} vakitlerinde ardışık doz atlamaları tespit edildi. "
                "Sisteme bu konuda size yardımcı olmasına izin verin."
            ),
            overall_score=overall_score,
            window_analyses=window_analyses,
        )

    if overall_score >= 0.85:
        return BehaviorProfileResult(
            profile_type="Düzenli Kullanıcı",
            profile_icon="⭐",
            description=(
                "Tedavinize düzenli uyum sağlıyorsunuz. "
                "Bu başarıyı sürdürmeniz sağlığınıza büyük katkı sağlar."
            ),
            overall_score=overall_score,
            window_analyses=window_analyses,
        )

    # Hangi pencere en iyi?
    valid = [w for w in window_analyses if w.planned > 0]
    if valid:
        best = max(valid, key=lambda w: w.local_score)
        if best.window == "morning" and best.local_score > 0.7:
            return BehaviorProfileResult(
                profile_type="Sabah Tipi",
                profile_icon="🌅",
                description=(
                    "Sabah dozlarını düzenli alıyorsunuz. "
                    "Öğle ve akşam dozlarına daha fazla dikkat etmeniz önerilir."
                ),
                overall_score=overall_score,
                window_analyses=window_analyses,
            )
        if best.window == "evening" and best.local_score > 0.7:
            return BehaviorProfileResult(
                profile_type="Akşam Tipi",
                profile_icon="🌙",
                description=(
                    "Akşam dozlarını düzenli alıyorsunuz. "
                    "Sabah ve öğle dozlarına daha fazla dikkat etmeniz önerilir."
                ),
                overall_score=overall_score,
                window_analyses=window_analyses,
            )

    return BehaviorProfileResult(
        profile_type="Gelişiyor",
        profile_icon="📈",
        description=(
            "Tedavi uyumunuzu artırmaktasınız. "
            "SmartDoz size daha düzenli olmak için öneriler sunacak."
        ),
        overall_score=overall_score,
        window_analyses=window_analyses,
    )


def _generate_xai_explanation(
    window: str,
    decision_type: str,
    delta_minutes: int = 0,
    avg_delay: float = 0.0,
    overall_score: float = 0.0,
    skip_reason: str = "",
) -> str:
    """
    XAI (Açıklanabilir Yapay Zeka): Kararın insan dilindeki gerekçesi.

    Kullanıcının bildirdiği sebep (skip_reason) varsa açıklamayı kişiselleştirir.
    """
    label = _WINDOW_LABELS.get(window, "")

    if decision_type == "DOCTOR_REFERRAL":
        if skip_reason == "Yan etki korkusu":
            return (
                "Birden fazla dozunuzu 'Yan etki korkusu' nedeniyle atladığınız tespit edildi. "
                "Bu endişeyi doktorunuza iletmeniz önerilir. "
                "Otomatik saat değişikliği yapılmayacak; önce uzman görüşü alınmalı."
            )
        return (
            f"{label} dozunuzla ilgili klinik bir risk tespit edildi. "
            "İlaç etkileşimleri nedeniyle hatırlatıcı saatinde otomatik değişiklik "
            "yapılmayacak. Durumu doktorunuzla görüşmeniz önerilir."
        )

    if decision_type == "LOGISTIC_REMINDER":
        if skip_reason == "İlaç bitti":
            return (
                "Dozlarınızı 'İlaç bitti' nedeniyle atladığınız tespit edildi. "
                "Her dozunuzdan 1 saat önce 'Stok kontrolü' hatırlatması eklemeniz faydalı olabilir."
            )
        return (
            "Dozlarınızı 'Yanımda yoktu' nedeniyle atladığınız tespit edildi. "
            "Her dozunuzdan 1 saat önce 'İlacınızı yanınıza almayı unutmayın' "
            "hatırlatması eklemenizi tavsiye ederim."
        )

    if decision_type == "SCHEDULE_SHIFT":
        direction = "ileri" if delta_minutes > 0 else "geri"
        return (
            f"{label} saatlerinde dozlarınızı ortalama {abs(avg_delay):.0f} dakika "
            f"geç aldığınız tespit edildi. Bu nedenle {label.lower()} hatırlatıcısını "
            f"{abs(delta_minutes)} dakika {direction} almanız önerilir."
        )

    if decision_type == "TONE_ADAPT":
        if skip_reason == "Uyuyordum":
            return (
                f"{label} dozlarınızı sıklıkla 'Uyuyordum' nedeniyle atladığınız tespit edildi. "
                "Cihazınızın alarm ses seviyesini ve titreşim ayarını yükseltmeniz tavsiye edilir."
            )
        if overall_score > _HIGH_ADHERENCE:
            pct = int(overall_score * 100)
            return (
                f"Tedavi uyumunuz %{pct} ile mükemmel! 🎉 "
                "Bu performansı sürdürmek için alarm tonunuzu daha yumuşak bir sesle "
                "güncellemeniz faydalı olabilir."
            )
        pct = int(overall_score * 100)
        return (
            f"Son dönemde tedavi uyumunuz %{pct} seviyesinde. "
            "Doz hatırlatmalarını daha dikkat çekici bir ses ile güçlendirmeniz "
            "tavsiye edilir. Bu küçük değişiklik uyumunuzu artırabilir."
        )

    if decision_type == "GAMIFICATION":
        if skip_reason == "Unuttum":
            return (
                f"{label} dozlarınızı sıklıkla 'Unuttum' nedeniyle atladığınız tespit edildi. "
                "Hatırlatma sıklığını artırmanız veya rozet/puan kazandıran bir motivasyon "
                "programı başlatmanız faydalı olabilir."
            )
        return (
            f"{label} hatırlatıcı saati değişikliğinin ardından yeterli iyileşme "
            "gözlemlenmedi. Size rozet ve puan kazandıran bir motivasyon programı "
            "başlatmanız tavsiye edilir."
        )

    return "Tedavi uyumunuzu iyileştirmek için bir öneri hazırlandı."


# ──────────────────────────────────────────────────────
# Ana Servis Sınıfı
# ──────────────────────────────────────────────────────

class DecisionEngine:
    """
    Modül 8: Kural Tabanlı YZ Karar Motoru (Algorithm 5 implementasyonu).

    Kullanım:
        engine = DecisionEngine()
        profile = await engine.analyze_user(user_id=1, db=session)
        new_decisions = await engine.generate_decisions(user_id=1, db=session)
    """

    # ── Genel Analiz ──────────────────────────────────

    async def analyze_user(
        self,
        user_id: int,
        db: AsyncSession,
        days: int = 30,
    ) -> BehaviorProfileResult:
        """
        Kullanıcının son ``days`` günlük davranış profilini analiz eder.

        Args:
            user_id: Hedef kullanıcı.
            db:      Aktif DB oturumu.
            days:    Analiz penceresi (varsayılan 30 gün).

        Returns:
            BehaviorProfileResult (profil tipi + pencere analizleri).
        """
        logs = await self._fetch_logs(user_id, db, days)
        return self._compute_profile(logs)

    def _compute_profile(self, logs: list[DoseLog]) -> BehaviorProfileResult:
        """Ham log listesinden profil hesapla (test edilebilir saf fonksiyon)."""
        # Lokal pencere analizleri
        by_window: dict[str, list[DoseLog]] = {
            "morning": [], "noon": [], "evening": []
        }
        for log in logs:
            w = _classify_window(log.scheduled_time.hour)
            by_window[w].append(log)

        window_analyses = [
            _analyze_window(by_window[w], w)
            for w in ("morning", "noon", "evening")
        ]

        # Genel uyum skoru (tüm pencereler)
        total_taken   = sum(w.taken   for w in window_analyses)
        total_planned = sum(w.planned for w in window_analyses)
        overall_score = (
            round(total_taken / total_planned, 4) if total_planned > 0 else 0.0
        )

        return _build_behavior_profile(window_analyses, overall_score)

    # ── Karar Üretimi ─────────────────────────────────

    async def generate_decisions(
        self,
        user_id: int,
        db: AsyncSession,
        days: int = 30,
    ) -> list[AIDecision]:
        """
        Kullanıcı için yeni YZ kararları üretir ve DB'ye kaydeder.

        Aynı ilaç + pencere kombinasyonu için aktif PENDING karar varsa
        tekrar üretmez (idempotent).

        Returns:
            Yeni oluşturulan AIDecision kayıtları.
        """
        logs  = await self._fetch_logs(user_id, db, days)
        meds  = await self._fetch_medications(user_id, db)
        clini = await self._check_clinical_risk(user_id, db, meds=meds)

        created: list[AIDecision] = []

        logger.info(
            "generate_decisions BAŞLADI: user=%d days=%d → %d log, %d ilaç",
            user_id, days, len(logs), len(meds),
        )

        # Her ilaç için ayrı pencere analizi
        for med in meds:
            med_logs = [l for l in logs if l.medication_id == med.id]
            logger.info(
                "  İlaç id=%d name=%r → %d log (toplam %d)",
                med.id, med.name, len(med_logs), len(logs),
            )
            if not med_logs:
                logger.info("    → log yok, atlanıyor")
                continue

            med_high_risk = clini.get(med.id, False)
            decisions_for_med = await self._decide_for_medication(
                user_id=user_id,
                med=med,
                logs=med_logs,
                has_clinical_risk=med_high_risk,
                db=db,
            )
            logger.info(
                "    → %d karar üretildi: %s",
                len(decisions_for_med),
                [d.decision_type for d in decisions_for_med],
            )
            for d in decisions_for_med:
                ai_dec = await self._persist_decision(d, user_id, db)
                if ai_dec:
                    created.append(ai_dec)

        # Kapalı döngü: takip süresi dolan kararların sonucunu değerlendir
        await self._evaluate_outcomes(user_id, logs, db)

        await db.flush()
        return created

    async def _decide_for_medication(
        self,
        user_id: int,
        med: Medication,
        logs: list[DoseLog],
        has_clinical_risk: bool,
        db: AsyncSession,
    ) -> list[DecisionResult]:
        """
        Tek bir ilaç için kural zincirini uygular.

        Kural sırası:
          0. Yan etki korkusu sebebi → DOCTOR_REFERRAL (öncelikli, erken çıkış)
          1. Klinik etkileşim riski  → DOCTOR_REFERRAL (erken çıkış)
          L. Lojistik sebep           → LOGISTIC_REMINDER (devam eder)
          U. Uyuyordum sebebi         → TONE_ADAPT alarm_boost
          2. Pencere bazlı sistematik sapma → SCHEDULE_SHIFT / GAMIFICATION
          3. Genel uyum skoru        → TONE_ADAPT (gentle / urgent)
        """
        results: list[DecisionResult] = []

        # Atlanma sebeplerini çıkar
        reason_counts = _reason_counts(logs)
        dominant_reason = _dominant_reason(logs)
        logger.info(
            "    Sebep analizi (ilaç=%r): %s dominant=%r",
            med.name, reason_counts, dominant_reason,
        )

        # ── Kural 0: Yan Etki Korkusu → Doktor Yönlendirme ──────────────
        # Kullanıcı "Yan etki korkusu" sebebini en az 1 kez bildirdiyse,
        # farmakolojik risk olarak ele alınır ve kliniksiz de DOCTOR_REFERRAL üretilir.
        if reason_counts.get("Yan etki korkusu", 0) >= 1:
            if not await self._has_pending(user_id, med.id, "DOCTOR_REFERRAL", db):
                results.append(DecisionResult(
                    decision_type="DOCTOR_REFERRAL",
                    time_window="all",
                    explanation=_generate_xai_explanation(
                        "all", "DOCTOR_REFERRAL", skip_reason="Yan etki korkusu"
                    ),
                    payload={
                        "medication_name": med.name,
                        "reason": "Yan etki korkusu",
                        "count": reason_counts["Yan etki korkusu"],
                    },
                    medication_id=med.id,
                ))
            return results  # Klinik öncelik: başka kural çalışmaz

        # ── Kural 1: Etkileşim Bazlı Klinik Risk ─────────────────────────
        if has_clinical_risk:
            if not await self._has_pending(user_id, med.id, "DOCTOR_REFERRAL", db):
                results.append(DecisionResult(
                    decision_type="DOCTOR_REFERRAL",
                    time_window="all",
                    explanation=_generate_xai_explanation("all", "DOCTOR_REFERRAL"),
                    payload={"medication_name": med.name},
                    medication_id=med.id,
                ))
            return results   # Klinik risk: başka kural çalışmaz

        # ── Kural Lojistik: Yanımda yoktu / İlaç bitti ───────────────────
        # Erişim engeli nedeniyle atlama → bir sonraki dozdan önce bağlamsal uyarı.
        _logistic_reasons = {"Yanımda yoktu", "İlaç bitti"}
        logistic_count = sum(reason_counts.get(r, 0) for r in _logistic_reasons)
        if logistic_count >= 1:
            if not await self._has_pending(user_id, med.id, "LOGISTIC_REMINDER", db):
                dominant_logistic = (
                    "İlaç bitti"
                    if reason_counts.get("İlaç bitti", 0) >= reason_counts.get("Yanımda yoktu", 0)
                    else "Yanımda yoktu"
                )
                results.append(DecisionResult(
                    decision_type="LOGISTIC_REMINDER",
                    time_window="all",
                    explanation=_generate_xai_explanation(
                        "all", "LOGISTIC_REMINDER", skip_reason=dominant_logistic
                    ),
                    payload={
                        "medication_name": med.name,
                        "reason": dominant_logistic,
                        "count": logistic_count,
                    },
                    medication_id=med.id,
                ))
            # Lojistik kural: diğer kurallar da çalışabilir (return yok)

        # Pencere analizleri oluştur
        by_window: dict[str, list[DoseLog]] = {
            "morning": [], "noon": [], "evening": []
        }
        for log in logs:
            w = _classify_window(log.scheduled_time.hour)
            by_window[w].append(log)

        window_analyses = {
            w: _analyze_window(by_window[w], w)
            for w in ("morning", "noon", "evening")
        }

        total_taken   = sum(a.taken   for a in window_analyses.values())
        total_planned = sum(a.planned for a in window_analyses.values())
        overall_score = (
            round(total_taken / total_planned, 4) if total_planned > 0 else 0.0
        )

        logger.info(
            "    Pencere Analizi (ilaç=%r): overall=%.2f total_planned=%d total_taken=%d",
            med.name, overall_score, total_planned, total_taken,
        )
        for w, a in window_analyses.items():
            logger.info(
                "      %s: planned=%d taken=%d score=%.2f consec_skips=%d avg_delay=%.1f has_dev=%s",
                w, a.planned, a.taken, a.local_score,
                a.consecutive_skips, a.avg_delay_minutes, a.has_systematic_deviation,
            )

        # ── Kural Uyku: Uyuyordum → TONE_ADAPT alarm_boost ───────────────
        # Uyku sebebi, saat kaydırmadan önce alarm gücü artışıyla çözülmeye çalışılır.
        if dominant_reason == "Uyuyordum":
            if not await self._has_pending(user_id, med.id, "TONE_ADAPT", db):
                results.append(DecisionResult(
                    decision_type="TONE_ADAPT",
                    time_window="all",
                    explanation=_generate_xai_explanation(
                        "all", "TONE_ADAPT", skip_reason="Uyuyordum"
                    ),
                    payload={
                        "mode": "alarm_boost",
                        "reason": "Uyuyordum",
                        "count": reason_counts.get("Uyuyordum", 0),
                    },
                    medication_id=med.id,
                ))

        # ── Kural 2: Sistematik Sapma → SCHEDULE_SHIFT / GAMIFICATION ────
        for window, analysis in window_analyses.items():
            if not analysis.has_systematic_deviation:
                logger.info("      [%s] sistematik sapma yok → atla", window)
                continue
            if analysis.local_score > _WINDOW_FAILURE_THRESHOLD:
                logger.info(
                    "      [%s] score=%.2f > eşik=%.2f → atla",
                    window, analysis.local_score, _WINDOW_FAILURE_THRESHOLD,
                )
                continue
            has_sched_pending = await self._has_pending(user_id, med.id, "SCHEDULE_SHIFT", db, window)
            if has_sched_pending:
                logger.info("      [%s] zaten PENDING SCHEDULE_SHIFT var → atla", window)
                continue

            avg_delay = analysis.avg_delay_minutes
            if avg_delay >= _DELAY_TRIGGER_MINUTES:
                delta = min(int(avg_delay), _MAX_SHIFT_MINUTES)
                logger.info("      [%s] SCHEDULE_SHIFT eklendi: delta=%d", window, delta)
                results.append(DecisionResult(
                    decision_type="SCHEDULE_SHIFT",
                    time_window=window,
                    explanation=_generate_xai_explanation(
                        window, "SCHEDULE_SHIFT",
                        delta_minutes=delta, avg_delay=avg_delay,
                    ),
                    payload={
                        "delta_minutes": delta,
                        "window": window,
                        "avg_delay_minutes": avg_delay,
                        "consecutive_skips": analysis.consecutive_skips,
                        "local_score": analysis.local_score,
                    },
                    medication_id=med.id,
                ))
            else:
                # Sapma var ama gecikme yoksa → GAMIFICATION
                # "Unuttum" sebebi varsa açıklama kişiselleştirilir.
                logger.info(
                    "      [%s] avg_delay=%.1f < %d → GAMIFICATION yolu",
                    window, avg_delay, _DELAY_TRIGGER_MINUTES,
                )
                if not await self._has_pending(user_id, med.id, "GAMIFICATION", db, window):
                    results.append(DecisionResult(
                        decision_type="GAMIFICATION",
                        time_window=window,
                        explanation=_generate_xai_explanation(
                            window, "GAMIFICATION",
                            overall_score=overall_score,
                            skip_reason=dominant_reason or "",
                        ),
                        payload={
                            "window": window,
                            "consecutive_skips": analysis.consecutive_skips,
                            "local_score": analysis.local_score,
                            "reason": dominant_reason,
                        },
                        medication_id=med.id,
                    ))

        # ── Kural 3: Ton Adaptasyonu (skor bazlı) ────────────────────────
        # Sadece yukarıdaki kurallar hiçbir karar üretmediyse devreye girer.
        if not results and total_planned >= 2:
            if overall_score > _HIGH_ADHERENCE:
                if not await self._has_pending(user_id, med.id, "TONE_ADAPT", db):
                    results.append(DecisionResult(
                        decision_type="TONE_ADAPT",
                        time_window="all",
                        explanation=_generate_xai_explanation(
                            "all", "TONE_ADAPT", overall_score=overall_score,
                        ),
                        payload={"mode": "gentle", "overall_score": overall_score},
                        medication_id=med.id,
                    ))
            elif overall_score < _LOW_ADHERENCE:
                if not await self._has_pending(user_id, med.id, "TONE_ADAPT", db):
                    results.append(DecisionResult(
                        decision_type="TONE_ADAPT",
                        time_window="all",
                        explanation=_generate_xai_explanation(
                            "all", "TONE_ADAPT", overall_score=overall_score,
                        ),
                        payload={"mode": "urgent", "overall_score": overall_score},
                        medication_id=med.id,
                    ))

        return results

    # ── Kapalı Döngü Geri Bildirim ────────────────────

    async def _evaluate_outcomes(
        self,
        user_id: int,
        current_logs: list[DoseLog],
        db: AsyncSession,
    ) -> None:
        """
        Takip süresi dolan APPROVED kararların sonucunu değerlendirir.
        Windows-specific uyum iyileşmesi > %10 → SUCCESS, değilse FAILURE.
        Başarısız müdahale sonrası GAMIFICATION kararı tetiklenir.
        """
        now = _now_istanbul()
        stmt = select(AIDecision).where(
            AIDecision.user_id == user_id,
            AIDecision.status == "APPROVED",
            AIDecision.outcome.is_(None),
            AIDecision.tracking_end <= now,
        )
        result = await db.execute(stmt)
        due_decisions = result.scalars().all()

        for decision in due_decisions:
            payload = json.loads(decision.payload or "{}")
            window  = payload.get("window") or decision.time_window
            pre_score = payload.get("local_score", 0.0)

            # Takip dönemi sonrasındaki uyum skoru
            post_logs = [
                l for l in current_logs
                if (
                    decision.tracking_start is not None
                    and l.scheduled_time >= decision.tracking_start
                    and (window == "all" or _classify_window(l.scheduled_time.hour) == window)
                )
            ]
            post_taken   = sum(1 for l in post_logs if l.status == "Alındı")
            post_planned = post_taken + sum(1 for l in post_logs if l.status == "Atlandı")
            post_score   = (post_taken / post_planned) if post_planned > 0 else 0.0

            improvement = post_score - pre_score
            if improvement >= 0.10:
                decision.outcome    = "SUCCESS"
                decision.resolved_at = now
                logger.info(
                    "AIDecision %d → SUCCESS (iyileşme: +%.1f%%)",
                    decision.id, improvement * 100,
                )
            else:
                decision.outcome    = "FAILURE"
                decision.resolved_at = now
                logger.info(
                    "AIDecision %d → FAILURE (iyileşme: %.1f%%)",
                    decision.id, improvement * 100,
                )
                # Başarısız müdahale → GAMIFICATION tetikle
                if decision.medication_id and window:
                    already_gamif = await self._has_pending(
                        user_id, decision.medication_id, "GAMIFICATION", db, window
                    )
                    if not already_gamif:
                        gamif = AIDecision(
                            user_id=user_id,
                            medication_id=decision.medication_id,
                            decision_type="GAMIFICATION",
                            time_window=window,
                            explanation=_generate_xai_explanation(
                                window or "all", "GAMIFICATION",
                            ),
                            payload=json.dumps({
                                "triggered_by_decision_id": decision.id,
                                "window": window,
                            }),
                            status="PENDING",
                            created_at=now,
                        )
                        db.add(gamif)

            db.add(decision)

    # ── Yardımcı DB Sorguları ─────────────────────────

    async def _fetch_logs(
        self,
        user_id: int,
        db: AsyncSession,
        days: int,
    ) -> list[DoseLog]:
        """Kullanıcının son ``days`` günlük DoseLog kayıtlarını getirir."""
        now          = _now_istanbul()
        period_start = now - timedelta(days=days)
        stmt = (
            select(DoseLog)
            .join(Medication, DoseLog.medication_id == Medication.id)
            .where(
                Medication.user_id == user_id,
                DoseLog.scheduled_time >= period_start,
            )
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    async def _fetch_medications(
        self,
        user_id: int,
        db: AsyncSession,
    ) -> list[Medication]:
        """Kullanıcının tüm ilaçlarını getirir."""
        stmt = select(Medication).where(Medication.user_id == user_id)
        result = await db.execute(stmt)
        return list(result.scalars().all())

    async def _check_clinical_risk(
        self,
        user_id: int,
        db: AsyncSession,
        meds: Optional[list[Medication]] = None,
    ) -> dict[int, bool]:
        """
        Kullanıcının ilaçları için YUKSEK klinik risk haritası döner.
        {medication_id: True/False}

        InteractionEngine ile senkron çalışır (bellek içi CSV).
        ``meds`` verilirse tekrar DB sorgusu yapmaz (generate_decisions ile paylaşım).
        """
        from services.interaction_engine import interaction_engine

        if meds is None:
            meds = await self._fetch_medications(user_id, db)
        risk_map: dict[int, bool] = {}

        other_drugs = [
            {"name": m.name, "atc_code": m.atc_code, "active_ingredient": m.active_ingredient}
            for m in meds
        ]

        for med in meds:
            has_high_risk = False
            others = [d for d in other_drugs if d["name"] != med.name]
            if others and interaction_engine.is_loaded:
                med_ingredient = med.active_ingredient or med.name
                for other in others:
                    other_ingredient = other.get("active_ingredient") or other["name"]
                    result = interaction_engine.lookup(
                        ingredient_a=med_ingredient,
                        ingredient_b=other_ingredient,
                    )
                    if result and result.get("risk_level") == "YUKSEK":
                        has_high_risk = True
                        break
            risk_map[med.id] = has_high_risk

        return risk_map

    async def _has_pending(
        self,
        user_id: int,
        medication_id: Optional[int],
        decision_type: str,
        db: AsyncSession,
        time_window: Optional[str] = None,
    ) -> bool:
        """
        Belirtilen kullanıcı/ilaç/tip/pencere kombinasyonu için
        aktif PENDING kararın varlığını kontrol eder (idempotency).
        """
        stmt = select(AIDecision).where(
            AIDecision.user_id == user_id,
            AIDecision.decision_type == decision_type,
            AIDecision.status == "PENDING",
        )
        if medication_id is not None:
            stmt = stmt.where(AIDecision.medication_id == medication_id)
        if time_window is not None:
            stmt = stmt.where(AIDecision.time_window == time_window)

        result = await db.execute(stmt)
        return result.scalars().first() is not None

    async def _persist_decision(
        self,
        decision: DecisionResult,
        user_id: int,
        db: AsyncSession,
    ) -> Optional[AIDecision]:
        """DecisionResult nesnesini AIDecision ORM kaydına dönüştürür ve DB'ye ekler."""
        now = _now_istanbul()
        ai_dec = AIDecision(
            user_id=user_id,
            medication_id=decision.medication_id,
            decision_type=decision.decision_type,
            time_window=decision.time_window,
            explanation=decision.explanation,
            payload=json.dumps(decision.payload),
            status="PENDING",
            created_at=now,
        )
        db.add(ai_dec)
        logger.info(
            "Yeni AIDecision üretildi: type=%s window=%s user=%d",
            decision.decision_type, decision.time_window, user_id,
        )
        return ai_dec

    # ── Karar Çözümleme ───────────────────────────────

    async def resolve_decision(
        self,
        decision_id: int,
        user_id: int,
        new_status: str,
        db: AsyncSession,
    ) -> AIDecision:
        """
        Kullanıcının onay/ret yanıtını işler.

        APPROVED → tracking_start ve tracking_end ayarlanır.
        REJECTED → resolved_at ayarlanır.

        Raises:
            ValueError: Karar bulunamazsa veya PENDING değilse.
        """
        stmt = select(AIDecision).where(
            AIDecision.id == decision_id,
            AIDecision.user_id == user_id,
        )
        result = await db.execute(stmt)
        decision = result.scalars().first()

        if not decision:
            raise ValueError(f"AIDecision id={decision_id} bulunamadı.")
        if decision.status != "PENDING":
            raise ValueError(
                f"Karar zaten çözümlendi: status={decision.status}"
            )

        now               = _now_istanbul()
        decision.status   = new_status
        decision.resolved_at = now

        if new_status == "APPROVED" and decision.decision_type == "SCHEDULE_SHIFT":
            decision.tracking_start = now
            decision.tracking_end   = now + timedelta(days=_TRACKING_DAYS)

        db.add(decision)
        await db.flush()
        return decision

    async def expire_stale_decisions(
        self,
        user_id: int,
        db: AsyncSession,
    ) -> int:
        """
        48 saati geçen PENDING kararları EXPIRED olarak işaretler.
        Returns: Süresi dolan karar sayısı.
        """
        now       = _now_istanbul()
        threshold = now - timedelta(hours=_DECISION_EXPIRY_HOURS)
        stmt = select(AIDecision).where(
            AIDecision.user_id == user_id,
            AIDecision.status == "PENDING",
            AIDecision.created_at <= threshold,
        )
        result = await db.execute(stmt)
        stale  = result.scalars().all()

        for dec in stale:
            dec.status      = "EXPIRED"
            dec.resolved_at = now
            db.add(dec)

        await db.flush()
        return len(stale)

    async def get_pending_decisions(
        self,
        user_id: int,
        db: AsyncSession,
    ) -> list[AIDecision]:
        """Kullanıcının bekleyen (PENDING) kararlarını döner."""
        stmt = (
            select(AIDecision)
            .where(
                AIDecision.user_id == user_id,
                AIDecision.status == "PENDING",
            )
            .order_by(AIDecision.created_at.desc())
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    async def get_recent_decisions(
        self,
        user_id: int,
        db: AsyncSession,
        limit: int = 10,
    ) -> list[AIDecision]:
        """Son çözümlenmiş (APPROVED/REJECTED/EXPIRED) kararları döner."""
        stmt = (
            select(AIDecision)
            .where(
                AIDecision.user_id == user_id,
                AIDecision.status.in_(["APPROVED", "REJECTED", "EXPIRED"]),
            )
            .order_by(AIDecision.resolved_at.desc())
            .limit(limit)
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    # ── Modül 8: Akıllı İpuçları (Sadece Öneri) ──────

    async def generate_smart_tips(
        self,
        user_id: int,
        db: AsyncSession,
        days: int = 7,
    ) -> list[dict]:
        """
        Algoritma 5 çıktılarını (reason_counts + overall_score) analiz ederek
        kullanıcıya metin tabanlı ipucu kartları üretir.

        Sistem hiçbir otomatik eylem yapmaz; sadece statik metin önerileri döner.
        Her ipucu, XAI prensibiyle üretilme gerekçesini de içerir.
        """
        logs = await self._fetch_logs(user_id, db, days)

        reason_counts   = _reason_counts(logs)
        dominant_reason = _dominant_reason(logs)

        total_taken   = sum(1 for l in logs if l.status == "Alındı")
        total_skipped = sum(1 for l in logs if l.status == "Atlandı")
        total_planned = total_taken + total_skipped
        overall_score = (
            round(total_taken / total_planned, 4) if total_planned > 0 else 0.0
        )
        overall_pct = int(overall_score * 100)

        has_clinical_risk = any(
            (await self._check_clinical_risk(user_id, db)).values()
        )

        tips: list[dict] = []

        # ── İpucu 1: Yan etki korkusu ─────────────────
        if reason_counts.get("Yan etki korkusu", 0) >= 1:
            count = reason_counts["Yan etki korkusu"]
            tips.append({
                "tip_id": "YAN_ETKI",
                "icon": "⚕️",
                "title": "Yan Etki Endişesi Fark Edildi",
                "message": (
                    "Bu ilacı yan etki nedeniyle atladığınızı fark ettim. "
                    "Lütfen bu durumu bir sonraki randevunuzda doktorunuza "
                    "sözlü olarak bildirmeyi unutmayın."
                ),
                "xai_reason": (
                    f"Son {days} günde 'Yan etki korkusu' gerekçesiyle "
                    f"{count} doz atladığınız için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "REASON_BASED",
            })

        # ── İpucu 2: Uyuyordum ────────────────────────
        if reason_counts.get("Uyuyordum", 0) >= 1:
            count = reason_counts["Uyuyordum"]
            tips.append({
                "tip_id": "UYKU",
                "icon": "😴",
                "title": "Sabah Dozu Kaçırılıyor",
                "message": (
                    "Sabah dozlarını uyku nedeniyle kaçırıyorsunuz. "
                    "İlaç saatinizi, uyandığınız daha geç bir saate "
                    "güncellemeyi düşünebilirsiniz."
                ),
                "xai_reason": (
                    f"Son {days} günde 'Uyuyordum' gerekçesiyle "
                    f"{count} doz atladığınız için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "REASON_BASED",
            })

        # ── İpucu 3: Unuttum ──────────────────────────
        if reason_counts.get("Unuttum", 0) >= 1:
            count = reason_counts["Unuttum"]
            tips.append({
                "tip_id": "UNUTMA",
                "icon": "💊",
                "title": "Doz Unutma Örüntüsü",
                "message": (
                    "Bu ilacı sıkça unuttuğunuzu görüyorum. "
                    "İlaç kutusunu görebileceğiniz bir yere (örneğin baş ucu "
                    "veya mutfak masası) koymak size yardımcı olabilir."
                ),
                "xai_reason": (
                    f"Son {days} günde 'Unuttum' gerekçesiyle "
                    f"{count} doz atladığınız için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "REASON_BASED",
            })

        # ── İpucu 4: Yanımda yoktu ────────────────────
        if reason_counts.get("Yanımda yoktu", 0) >= 1:
            count = reason_counts["Yanımda yoktu"]
            tips.append({
                "tip_id": "LOJISTIK",
                "icon": "🎒",
                "title": "İlaç Yanınızda Değildi",
                "message": (
                    "İlacınızı yanınızda taşımadığınız için doz kaçırdığınızı "
                    "görüyorum. Eve çıkmadan önce çantanıza veya cebinize "
                    "bir doz koymayı alışkanlık haline getirmeyi "
                    "düşünebilirsiniz."
                ),
                "xai_reason": (
                    f"Son {days} günde 'Yanımda yoktu' gerekçesiyle "
                    f"{count} doz atladığınız için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "REASON_BASED",
            })

        # ── İpucu 5: İlaç bitti ───────────────────────
        if reason_counts.get("İlaç bitti", 0) >= 1:
            count = reason_counts["İlaç bitti"]
            tips.append({
                "tip_id": "STOK",
                "icon": "🏥",
                "title": "İlaç Stoğu Bitti",
                "message": (
                    "Stoğunuz bittiği için doz atladığınızı görüyorum. "
                    "İlacınızın son 3-4 tableti kaldığında eczaneye gitmeyi "
                    "kendinize hatırlatmak, gelecekte bu sorunu önleyecektir."
                ),
                "xai_reason": (
                    f"Son {days} günde 'İlaç bitti' gerekçesiyle "
                    f"{count} doz atladığınız için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "REASON_BASED",
            })

        # ── İpucu 6: Klinik risk ──────────────────────
        if has_clinical_risk and not any(t["tip_id"] == "YAN_ETKI" for t in tips):
            tips.append({
                "tip_id": "ETKILESIM",
                "icon": "⚠️",
                "title": "İlaç Etkileşimi Uyarısı",
                "message": (
                    "Kullandığınız ilaçlar arasında klinik düzeyde bir "
                    "etkileşim tespit ettim. Lütfen bu durumu doktorunuza "
                    "veya eczacınıza bildirin."
                ),
                "xai_reason": (
                    "İlaç etkileşim veritabanında yüksek riskli bir "
                    "etkileşim kaydı bulunduğu için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "ADHERENCE_BASED",
            })

        # ── İpucu 7: İsteksizlik / diğer sebepler ────
        other_reasons = {k: v for k, v in reason_counts.items()
                         if k not in {"Yan etki korkusu","Uyuyordum","Unuttum",
                                      "Yanımda yoktu","İlaç bitti"}}
        if other_reasons:
            total_other = sum(other_reasons.values())
            reasons_str = ", ".join(f"'{r}'" for r in other_reasons)
            tips.append({
                "tip_id": "ISTEKSIZLIK",
                "icon": "🙏",
                "title": "Farklı Bir Sebeple Atlama",
                "message": (
                    "Bazı dozları farklı sebeplerle atladığınızı görüyorum. "
                    "Tedavinize uyum sağlamak zor gelebilir; bu konuşmayı "
                    "bir sonraki doktor ziyaretinizde gündeme taşımanızı "
                    "öneririm."
                ),
                "xai_reason": (
                    f"Son {days} günde {reasons_str} gerekçesiyle "
                    f"toplam {total_other} doz atladığınız için bu "
                    "tavsiyeyi veriyorum."
                ),
                "tip_type": "REASON_BASED",
            })

        # ── İpucu 8: Düşük uyum (sebepsiz) ──────────
        if overall_score < _LOW_ADHERENCE and total_planned >= 3 and not tips:
            tips.append({
                "tip_id": "DUSUK_UYUM",
                "icon": "📉",
                "title": "Uyum Puanınız Düşük",
                "message": (
                    "Son bir haftadır tedavi uyumunuz oldukça düşük. "
                    "Düzenli ilaç kullanımı tedavinin en kritik adımıdır. "
                    "Herhangi bir engel hissediyorsanız doktorunuzla "
                    "paylaşmanızı öneririm."
                ),
                "xai_reason": (
                    f"Son {days} günlük uyum puanınız %{overall_pct} "
                    f"olduğu için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "ADHERENCE_BASED",
            })

        # ── İpucu 9: Genel pozitif ────────────────────
        if overall_score >= 0.90 and total_planned >= 3 and not tips:
            tips.append({
                "tip_id": "GENEL",
                "icon": "⭐",
                "title": "Harika Gidiyorsunuz!",
                "message": (
                    "Tedavinize mükemmel uyum sağlıyorsunuz. "
                    "Bu düzeni korumak uzun vadeli sağlığınıza "
                    "büyük katkı sağlayacak."
                ),
                "xai_reason": (
                    f"Son {days} günlük uyum puanınız %{overall_pct} "
                    "olduğu için bu tavsiyeyi veriyorum."
                ),
                "tip_type": "ADHERENCE_BASED",
            })

        return tips


# Uygulama genelinde tek örnek
decision_engine = DecisionEngine()
