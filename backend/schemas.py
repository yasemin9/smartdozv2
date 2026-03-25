"""
SmartDoz - Pydantic Şemaları (Request / Response Doğrulama)

Tüm API giriş/çıkış veri yapıları burada tanımlanır.
"""
from datetime import date, datetime, time
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator


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
    interaction_warnings: List[InteractionWarningResponse] = Field(default_factory=list)

    model_config = {"from_attributes": True}


# ──────────────────────────────────────────────────────
# Kullanıcı Tercihleri Şemaları
# ──────────────────────────────────────────────────────

class UserPreferenceUpdate(BaseModel):
    """Uyanma / uyuma saati güncelleme isteği."""
    wake_time: time
    sleep_time: time

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

    model_config = {"from_attributes": True}


# ──────────────────────────────────────────────────────
# Doz Takip Şemaları
# ──────────────────────────────────────────────────────

VALID_STATUSES = {"Alındı", "Atlandı", "Ertelendi"}


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
