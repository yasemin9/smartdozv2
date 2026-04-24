"""
SmartDoz - Pydantic Şemaları (Request / Response Doğrulama)

Tüm API giriş/çıkış veri yapıları burada tanımlanır.
"""
from datetime import date, datetime, time
from typing import List, Optional

import re as _re

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


# ──────────────────────────────────────────────────────
# Kullanıcı Şemaları
# ──────────────────────────────────────────────────────

class UserCreate(BaseModel):
    """Kayıt (Register) isteği."""
    first_name: str
    last_name: str
    email: EmailStr
    password: str

    @field_validator("first_name", "last_name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Bu alan boş olamaz.")
        if len(v) < 2:
            raise ValueError("En az 2 karakter olmalıdır.")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Şifre en az 8 karakter olmalıdır.")
        return v


class UserLogin(BaseModel):
    """Giriş (Login) isteği."""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """Kullanıcı bilgilerini döndürürken kullanılır (şifre hariç)."""
    id: int
    first_name: str
    last_name: str
    email: str

    model_config = {"from_attributes": True}


# ──────────────────────────────────────────────────────
# Token Şeması
# ──────────────────────────────────────────────────────

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ──────────────────────────────────────────────────────
# İlaç Şemaları
# ──────────────────────────────────────────────────────

class MedicationCreate(BaseModel):
    """Yeni ilaç oluşturma isteği."""
    name: str
    dosage_form: str
    usage_frequency: str
    usage_time: str
    expiry_date: date
    active_ingredient: Optional[str] = None
    atc_code: Optional[str] = None
    barcode: Optional[str] = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("İlaç adı boş olamaz.")
        return v

    @field_validator("expiry_date")
    @classmethod
    def validate_expiry(cls, v: date) -> date:
        if v < date.today():
            raise ValueError("Son kullanma tarihi geçmişte olamaz.")
        return v

    @model_validator(mode="after")
    def validate_usage_time_format(self) -> "MedicationCreate":
        """
        Saatlik aralık seçildiğinde usage_time alanının
        HH:MM formatında (00:00-23:59) olmasını zorunlu kılar.
        Kategorik sıklıklarda (Günde 1 kez vb.) doğrulama yapılmaz.
        """
        freq = (self.usage_frequency or "").lower()
        if "her" in freq and "saat" in freq:
            if not _re.match(r"^([01]\d|2[0-3]):[0-5]\d$", self.usage_time or ""):
                raise ValueError(
                    "Saatlik aralık seçildiğinde 'usage_time' HH:MM formatında "
                    "olmalıdır (örn: 08:00)."
                )
        return self


class MedicationUpdate(BaseModel):
    """Kısmi güncelleme — tüm alanlar opsiyonel."""
    name: Optional[str] = None
    dosage_form: Optional[str] = None
    usage_frequency: Optional[str] = None
    usage_time: Optional[str] = None
    expiry_date: Optional[date] = None
    active_ingredient: Optional[str] = None
    atc_code: Optional[str] = None
    barcode: Optional[str] = None


class InteractionWarningResponse(BaseModel):
    """UYARIOLUSTUR formatında gösterilecek etkileşim uyarısı."""
    with_medication_name: str
    description: str


class CriticalInteractionWarningResponse(BaseModel):
    """Algoritma 2 — deterministik ikili ATC etkileşim uyarısı."""
    risk_level: str  # YUKSEK_SEVIYE
    title: str
    message: str
    medication_a: str
    medication_b: str
    atc_a: str
    atc_b: str
    description: str


class MedicationResponse(BaseModel):
    """İlaç kaydı yanıtı."""
    id: int
    user_id: int
    name: str
    dosage_form: str
    usage_frequency: str
    usage_time: str
    expiry_date: date
    active_ingredient: Optional[str] = None
    atc_code: Optional[str] = None
    barcode: Optional[str] = None
    prospectus_link: Optional[str] = None
    interaction_warnings: List[InteractionWarningResponse] = Field(default_factory=list)

    model_config = {"from_attributes": True}


# ──────────────────────────────────────────────────────
# Kullanıcı Tercihleri Şemaları
# ──────────────────────────────────────────────────────

class UserPreferenceUpdate(BaseModel):
    """Uyanma / uyuma saati ve günlük rutin güncelleme isteği."""
    wake_time: time
    sleep_time: time
    breakfast_time: Optional[time] = None
    lunch_time:     Optional[time] = None
    dinner_time:    Optional[time] = None
    bedtime:        Optional[time] = None

    @field_validator("sleep_time")
    @classmethod
    def validate_sleep(cls, v: time, info) -> time:
        wake = info.data.get("wake_time")
        if wake and v == wake:
            raise ValueError("Uyanma ve uyuma saati aynı olamaz.")
        return v


class UserPreferenceResponse(BaseModel):
    wake_time: time
    sleep_time: time
    breakfast_time: Optional[time] = None
    lunch_time:     Optional[time] = None
    dinner_time:    Optional[time] = None
    bedtime:        Optional[time] = None

    model_config = {"from_attributes": True}


# ──────────────────────────────────────────────────────
# Doz Takip Şemaları
# ──────────────────────────────────────────────────────

VALID_STATUSES = {"Alındı", "Atlandı", "Ertelendi"}
VALID_SNOOZE_MINUTES = {5, 10, 15}


class DoseLogStatusUpdate(BaseModel):
    """Doz durumu güncelleme isteği."""
    status: str
    notes: Optional[str] = None

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in VALID_STATUSES:
            raise ValueError(f"Geçersiz durum. Seçenekler: {VALID_STATUSES}")
        return v


class SnoozeRequest(BaseModel):
    """Erteleme isteği — Modül 2 (Hatırlatıcı Sistemi)."""
    minutes: int = Field(..., description="Erteleme süresi: 5, 10 veya 15 dakika.")

    @field_validator("minutes")
    @classmethod
    def validate_minutes(cls, v: int) -> int:
        if v not in VALID_SNOOZE_MINUTES:
            raise ValueError(
                f"Geçersiz erteleme süresi. İzin verilenler: {sorted(VALID_SNOOZE_MINUTES)} dakika."
            )
        return v


class DoseLogResponse(BaseModel):
    """Doz log yanıtı — ilaç adı ve kullanıcı bilgisiyle zenginleştirilmiş."""
    id: int
    medication_id: int
    medication_name: str
    dosage_form: str
    scheduled_time: datetime
    actual_time: Optional[datetime] = None
    status: str
    notes: Optional[str] = None

    model_config = {"from_attributes": True}


class MedicationScheduleDoseResponse(BaseModel):
    """Takvimde seçilen güne ait doz girdisi (gerçek veya sanal)."""
    id: int
    medication_id: int
    medication_name: str
    dosage_form: str
    scheduled_time: datetime
    actual_time: Optional[datetime] = None
    status: str
    notes: Optional[str] = None
    is_virtual: bool = False


class MedicationScheduleResponse(BaseModel):
    """Evrensel doz sorgulama yanıtı: geçmiş, bugün veya gelecek."""
    date: str
    mode: str  # past | today | future
    dose_logs: List[MedicationScheduleDoseResponse]


class GlobalMedicationSearchResult(BaseModel):
    """Global ilaç arama sonucu — Modül 1 TypeAhead ve Modül 3 etkileşim için."""
    id: int
    product_name: str
    active_ingredient: Optional[str] = None
    atc_code: Optional[str] = None
    barcode: Optional[str] = None
    category_1: Optional[str] = None
    category_2: Optional[str] = None
    category_3: Optional[str] = None
    category_4: Optional[str] = None
    category_5: Optional[str] = None
    description: Optional[str] = None

    model_config = {"from_attributes": True}


# ──────────────────────────────────────────────────────
# Modül 3 — İlaç Etkileşim Şemaları
# ──────────────────────────────────────────────────────

class DrugInfo(BaseModel):
    """Etkileşim kontrolüne gönderilecek ilaç bilgisi."""
    name: Optional[str] = None
    atc_code: Optional[str] = None
    active_ingredient: Optional[str] = None
    barcode: Optional[str] = None


class InteractionCheckRequest(BaseModel):
    """POST /interactions/check-interaction istek gövdesi."""
    new_drug: DrugInfo
    existing_drugs: List[DrugInfo]


class InteractionResult(BaseModel):
    """Tek bir ilaç çifti için etkileşim sonucu."""
    with_drug_name: str
    risk_level: str          # YUKSEK | ORTA | DUSUK
    description: str         # Türkçeye çevrilmiş açıklama
    matched_by: str          # EXACT | LEVENSHTEIN
    confidence_score: float  # 0.0 – 1.0


class InteractionCheckResponse(BaseModel):
    """POST /interactions/check-interaction yanıtı."""
    new_drug_name: str
    resolved_ingredient: str
    interactions: List[InteractionResult]
    has_high_risk: bool


# ──────────────────────────────────────────────────────
# Takvim Şemaları
# ──────────────────────────────────────────────────────

class DailySummary(BaseModel):
    """Bir güne ait doz özeti."""
    date: str           # "YYYY-MM-DD"
    total: int
    taken: int
    missed: int
    postponed: int
    pending: int
    compliance_rate: float  # 0.0 – 1.0


class DailyCalendarResponse(BaseModel):
    """Günlük takvim verisi."""
    date: str
    dose_logs: List[DoseLogResponse]


class MonthlyCalendarResponse(BaseModel):
    """Aylık takvim özeti — her gün için uyum istatistiği."""
    year: int
    month: int
    summary: dict[str, DailySummary]


# ──────────────────────────────────────────────────────
# Modül 7 — Analitik Şemaları
# ──────────────────────────────────────────────────────

class WeeklyTrendPointResponse(BaseModel):
    """Bir haftaya ait MPR uyum noktası."""
    week_label: str          # ör. "16/03 - 22/03"
    week_start: str          # ISO 8601, ör. "2025-03-16"
    planned: int
    taken: int
    skipped: int
    postponed: int
    adherence_score: float   # 0.0 – 1.0


class AdherenceSummaryResponse(BaseModel):
    """Son N günlük genel MPR uyum özeti."""
    period_start: str
    period_end: str
    total_planned: int
    total_taken: int
    total_skipped: int
    total_postponed: int
    adherence_score: float   # 0.0 – 1.0
    weekly_trend: List[WeeklyTrendPointResponse]


class MissedHourSlot(BaseModel):
    """Belirli bir saate ait atlanmış doz sayısı."""
    hour: int               # 0–23
    missed_count: int


class MissedDaySlot(BaseModel):
    """Belirli bir haftanın gününe ait atlanmış doz sayısı."""
    day_of_week: int        # 0=Pazartesi … 6=Pazar
    day_name: str           # ör. "Pazartesi"
    missed_count: int


class BehavioralDeviationResponse(BaseModel):
    """Kullanıcının davranışsal sapma istatistikleri."""
    period_days: int
    total_skipped: int
    missed_by_hour: List[MissedHourSlot]   # Saate göre en çok kaçırılan dilimler
    missed_by_day: List[MissedDaySlot]     # Güne göre en çok kaçırılan dilimler
    peak_miss_hour: Optional[int] = None   # En çok kaçırılan saat
    peak_miss_day: Optional[str] = None    # En çok kaçırılan gün adı


# ──────────────────────────────────────────────────────
# Modül 8 — YZ Destekli Akıllı Özellikler Şemaları
# ──────────────────────────────────────────────────────

class TimeWindowScore(BaseModel):
    """Bir zaman penceresi için lokal uyum skoru."""
    window: str          # morning | noon | evening
    label: str           # Sabah | Öğle | Akşam
    planned: int
    taken: int
    local_score: float   # 0.0 – 1.0
    consecutive_skips: int


class BehaviorProfile(BaseModel):
    """Kullanıcının YZ tarafından belirlenen davranış profili."""
    profile_type: str       # Sabah Tipi | Akşam Tipi | Düzenli Kullanıcı | Sistematik Sapma | Gelişiyor
    profile_icon: str       # emoji veya icon adı
    description: str        # Kullanıcıya gösterilen profil açıklaması
    overall_score: float    # 0.0 – 1.0
    window_scores: List[TimeWindowScore]


class AIDecisionResponse(BaseModel):
    """Bir YZ müdahale kararının tam detayı."""
    id: int
    medication_id: Optional[int] = None
    medication_name: Optional[str] = None
    decision_type: str      # SCHEDULE_SHIFT | TONE_ADAPT | DOCTOR_REFERRAL | GAMIFICATION
    time_window: Optional[str] = None
    explanation: str        # XAI doğal dil açıklaması
    payload: Optional[dict] = None   # Yapısal detaylar (delta_minutes vb.)
    status: str             # PENDING | APPROVED | REJECTED | EXPIRED
    outcome: Optional[str] = None    # SUCCESS | FAILURE | None
    created_at: datetime
    resolved_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class AIDecisionResolve(BaseModel):
    """Kullanıcının bir karara verdiği yanıt."""
    status: str   # APPROVED | REJECTED

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in {"APPROVED", "REJECTED"}:
            raise ValueError("Geçersiz durum. Seçenekler: APPROVED, REJECTED")
        return v


class AIProfileResponse(BaseModel):
    """Modül 8 ana yanıtı: Kişisel profil + bekleyen kararlar."""
    behavior_profile: BehaviorProfile
    pending_decisions: List[AIDecisionResponse]
    recent_decisions: List[AIDecisionResponse]


class SmartTipResponse(BaseModel):
    """Modül 8 — Metin tabanlı akıllı ipucu kartı (sadece öneri, hiçbir otomatik eylem yok)."""
    tip_id: str        # Benzersiz tip türü: YAN_ETKI | UYKU | UNUTMA | LOJISTIK | STOK | ETKILESIM | ISTEKSIZLIK | DUSUK_UYUM | GENEL
    icon: str          # Emoji ikonu
    title: str         # Kısa başlık
    message: str       # Kullanıcıya gösterilecek tavsiye metni
    xai_reason: str    # XAI: Bu ipucunun neden üretildiğine dair şeffaf açıklama
    tip_type: str      # REASON_BASED | ADHERENCE_BASED


# ──────────────────────────────────────────────────────
# Modül 4 — OCR İlaç Tanıma Şemaları
# ──────────────────────────────────────────────────────

class OCRMatchCandidate(BaseModel):
    """
    Algoritma 3 — Levenshtein sonucu: tek bir aday eşleşme.

    Alanlar:
        medication_name: global_medications tablosundaki orijinal ürün adı.
        similarity:      Levenshtein benzerlik oranı [0.0, 1.0].
                         1.0 = tam eşleşme, 0.85 = minimum kabul edilen eşik.
    """
    medication_name: str
    similarity: float = Field(..., ge=0.0, le=1.0)


class OCRScanResponse(BaseModel):
    """
    POST /ocr/scan endpoint yanıtı.

    Alanlar:
        ocr_raw_text: OCR'dan çıkan ham metin (temizlenmiş).
        candidates:   Levenshtein ≥ %85 olan adaylar, azalan benzerlik sırasında.
                      Boş liste: OCR metin bulamadı veya eşik geçen ilaç yok.
    """
    ocr_raw_text: str
    candidates: List[OCRMatchCandidate]


# (Bu satırları var olan schemas.py'ye ekle)

from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ProspectusResponse(BaseModel):
    """Prospektüs listeleme cevabı"""
    id: int
    product_name: str
    is_summarized: bool
    summary_created_at: Optional[str] = None

    class Config:
        from_attributes = True


class ProspectusDetailResponse(BaseModel):
    """Prospektüs detay cevabı"""
    id: int
    product_name: str
    prospectus_link: str
    summary_text: str
    is_summarized: bool
    last_updated: str

    class Config:
        from_attributes = True
