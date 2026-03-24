"""
SmartDoz - Pydantic Şemaları (Request / Response Doğrulama)

Tüm API giriş/çıkış veri yapıları burada tanımlanır.
"""
from datetime import date
from typing import Optional

from pydantic import BaseModel, EmailStr, field_validator


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


class MedicationResponse(BaseModel):
    """İlaç kaydı yanıtı."""
    id: int
    user_id: int
    name: str
    dosage_form: str
    usage_frequency: str
    usage_time: str
    expiry_date: date

    model_config = {"from_attributes": True}
