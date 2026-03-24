"""
SmartDoz - Güvenlik: SHA-256 Tuzlanmış Şifreleme ve JWT Yönetimi

Doküman Referansı (EK1_revize.pdf): SHA-256 tabanlı, her kullanıcıya özgü
rastgele salt ile şifre saklama. Sabit-zamanlı karşılaştırma ile
timing-attack koruması sağlanmaktadır.
"""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

from core.config import settings


# ──────────────────────────────────────────────────────
# Şifre İşlemleri
# ──────────────────────────────────────────────────────

def _generate_salt() -> str:
    """Kriptografik olarak güvenli 32 byte'lık hex salt üretir."""
    return secrets.token_hex(32)


def hash_password(plain_password: str) -> str:
    """
    Şifreyi SHA-256 + tuz (salt) ile özetler.
    Saklama formatı: '<salt>$<sha256_hex_digest>'
    """
    salt = _generate_salt()
    digest = hashlib.sha256(f"{salt}{plain_password}".encode("utf-8")).hexdigest()
    return f"{salt}${digest}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Girilen şifreyi veritabanındaki hash ile doğrular.
    Timing-attack'a karşı secrets.compare_digest kullanılır.
    """
    try:
        salt, stored_digest = hashed_password.split("$", 1)
    except ValueError:
        return False

    computed_digest = hashlib.sha256(
        f"{salt}{plain_password}".encode("utf-8")
    ).hexdigest()

    return secrets.compare_digest(computed_digest, stored_digest)


# ──────────────────────────────────────────────────────
# JWT İşlemleri
# ──────────────────────────────────────────────────────

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """
    Verilen payload ile imzalı JWT access token üretir.
    Varsayılan süre: settings.ACCESS_TOKEN_EXPIRE_MINUTES
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode["exp"] = expire
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    """
    JWT token'ı doğrular ve payload sözlüğünü döner.
    Geçersiz/süresi dolmuş token için JWTError fırlatır.
    """
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
