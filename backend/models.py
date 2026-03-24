"""
SmartDoz - SQLAlchemy ORM Modelleri

Tablolar:
    users        — Kullanıcı hesapları
    medications  — Kullanıcıya ait ilaç kayıtları (FK: users.id)
"""
from datetime import date

from sqlalchemy import Date, ForeignKey, String, Integer
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
    # Dozaj formu: tablet, şurup, kapsül, enjeksiyon, damla, krem, vb.
    dosage_form: Mapped[str] = mapped_column(String(50), nullable=False)
    # Kullanım sıklığı: "Günde 2 kez", "Her 8 saatte bir", vb.
    usage_frequency: Mapped[str] = mapped_column(String(100), nullable=False)
    # Kullanım zamanı: "Sabah", "Yemekten önce", vb.
    usage_time: Mapped[str] = mapped_column(String(100), nullable=False)
    expiry_date: Mapped[date] = mapped_column(Date, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="medications")

    def __repr__(self) -> str:
        return f"<Medication id={self.id} name={self.name!r} user_id={self.user_id}>"
