"""
SmartDoz - SQLAlchemy ORM Modelleri

Tablolar:
    users            — Kullanıcı hesapları
    medications      — Kullanıcıya ait ilaç kayıtları (FK: users.id)
    user_preferences — Kullanıcı uyku/uyanma tercihleri (FK: users.id)
    dose_logs        — Doz takip kayıtları (FK: medications.id)
    ai_decisions     — Modül 8: Yapay Zeka müdahale kararları (FK: users.id)
"""
from datetime import date, datetime, time
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, Integer, Text, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class User(Base):
    """Kayıtlı kullanıcılar."""
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    # SHA-256 tuzlanmış hash: '<salt>$<digest>' formatında saklanır
    hashed_password: Mapped[str] = mapped_column(String(512), nullable=False)

    medications: Mapped[list["Medication"]] = relationship(
        "Medication",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="select",
    )
    preference: Mapped[Optional["UserPreference"]] = relationship(
        "UserPreference",
        back_populates="user",
        cascade="all, delete-orphan",
        uselist=False,
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email!r}>"


class Medication(Base):
    """Kullanıcıya ait ilaç kayıtları."""
    __tablename__ = "medications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    dosage_form: Mapped[str] = mapped_column(String(50), nullable=False)
    usage_frequency: Mapped[str] = mapped_column(String(100), nullable=False)
    usage_time: Mapped[str] = mapped_column(String(100), nullable=False)
    expiry_date: Mapped[date] = mapped_column(Date, nullable=False)
    # Modül 3 etkileşim kontrolünde kullanılacak ek metadata
    active_ingredient: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    atc_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    barcode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="medications")
    dose_logs: Mapped[list["DoseLog"]] = relationship(
        "DoseLog",
        back_populates="medication",
        cascade="all, delete-orphan",
        lazy="select",
    )

    def __repr__(self) -> str:
        return f"<Medication id={self.id} name={self.name!r} user_id={self.user_id}>"


class UserPreference(Base):
    """
    Kullanıcı hatırlatıcı tercihleri.
    ZAMANDILIMIHESAPLA algoritması bu tercihlerle çalışır (EK1_revize.pdf s.37).
    """
    __tablename__ = "user_preferences"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True,
    )
    # Uyanma ve uyku saatleri — algoritma parametreleri
    wake_time: Mapped[time] = mapped_column(Time, nullable=False, default=time(8, 0))
    sleep_time: Mapped[time] = mapped_column(Time, nullable=False, default=time(22, 0))

    user: Mapped["User"] = relationship("User", back_populates="preference")

    def __repr__(self) -> str:
        return f"<UserPreference user_id={self.user_id} wake={self.wake_time}>"


class DoseLog(Base):
    """
    Doz takip kayıtları.
    Her ilaç için planlanan ve gerçekleşen alım bilgisini tutar.

    Durum seçenekleri:
        Bekliyor  — Henüz zamanı gelmemiş/geçmemiş
        Alındı    — Kullanıcı tarafından onaylandı
        Atlandı   — Alınmadı (otomatik veya manuel)
        Ertelendi — Kullanıcı erteledi (+30 dk)
    """
    __tablename__ = "dose_logs"

    # Aynı ilaç için aynı planlanan saatte sadece 1 log olabilir
    __table_args__ = (
        UniqueConstraint("medication_id", "scheduled_time", name="uq_dose_log_med_time"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    medication_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("medications.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    scheduled_time: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, index=True
    )
    actual_time: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # Bekliyor | Alındı | Atlandı | Ertelendi
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="Bekliyor")
    notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # Davranış analizi: Ertelendi→Alındı geçişinde True olarak işaretlenir.
    was_postponed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    medication: Mapped["Medication"] = relationship("Medication", back_populates="dose_logs")


class GlobalMedication(Base):
    """
    Global ilaç veritabanı — ilac.json'dan beslenir.
    Modül 1 TypeAhead araması ve Modül 3 ilaç etkileşim kontrolü için kullanılır.
    """
    __tablename__ = "global_medications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    barcode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, index=True)
    atc_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True, index=True)
    active_ingredient: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    product_name: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    category_1: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    category_2: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    category_3: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    category_4: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    category_5: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    def __repr__(self) -> str:
        return f"<GlobalMedication id={self.id} product_name={self.product_name!r}>"


class AIDecision(Base):
    """
    Modül 8: Yapay Zeka Destekli Müdahale Kararları

    Her otomatik YZ önerisi burada kayıt altına alınır.
    Kullanıcı onaylayabilir (APPROVED) veya reddedebilir (REJECTED).
    Kapalı döngü geri bildirim: onaylanan kararlar 7 gün takip edilir.

    decision_type seçenekleri:
        SCHEDULE_SHIFT   — Hatırlatıcı saatini otomatik kaydır
        TONE_ADAPT       — Alarm tonunu uyum skoruna göre ayarla
        DOCTOR_REFERRAL  — Klinik risk; doktora yönlendir
        GAMIFICATION     — Başarısız müdahale sonrası oyunlaştırma

    status seçenekleri:
        PENDING  — Kullanıcı henüz karar vermedi
        APPROVED — Kullanıcı onayladı
        REJECTED — Kullanıcı reddetti
        EXPIRED  — Kullanıcı 48 saat içinde yanıt vermedi

    outcome (kapalı döngü):
        SUCCESS  — 7 günlük takipte uyum iyileşti
        FAILURE  — 7 günlük takipte iyileşme görülmedi
    """
    __tablename__ = "ai_decisions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    medication_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("medications.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )
    # Karar tipi
    decision_type: Mapped[str] = mapped_column(String(50), nullable=False)
    # Zaman penceresi: morning | noon | evening | all
    time_window: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # XAI: kullanıcıya gösterilecek doğal dil açıklaması
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    # Müdahale detayları — JSON: {"delta_minutes": 15, "window": "morning"}
    payload: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # Durum
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="PENDING")
    # Kapalı döngü geri bildirim sonucu
    outcome: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # Zaman damgaları
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    tracking_start: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    tracking_end: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    user: Mapped["User"] = relationship("User")
    medication: Mapped[Optional["Medication"]] = relationship("Medication")

    def __repr__(self) -> str:
        return (
            f"<AIDecision id={self.id} type={self.decision_type!r} "
            f"status={self.status!r} user_id={self.user_id}>"
        )
