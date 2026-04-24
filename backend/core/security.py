"""
SmartDoz - Güvenlik: SHA-256 Tuzlanmış Şifreleme ve JWT Yönetimi (Async Uyumlu)
"""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession # Session yerine AsyncSession
from sqlalchemy import select, or_ # Query yerine select kullanacağız
from typing import Optional
import jwt
import logging

from core.config import settings
from database import get_db
from models import User

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)

# ──────────────────────────────────────────────────────
# Kimlik Doğrulama (Dependency) - ASYNC DÜZELTİLDİ
# ──────────────────────────────────────────────────────

async def get_current_user(
    token_obj = Depends(security),
    db: AsyncSession = Depends(get_db) # AsyncSession olarak güncelledik
) -> Optional[User]:
    if not token_obj:
        return None
    
    token = token_obj.credentials
    
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        user_id = payload.get("sub")
        
        if user_id is None:
            raise HTTPException(status_code=401, detail="Geçersiz token")
            
    except Exception:
        raise HTTPException(status_code=401, detail="Token doğrulanamadı")
    
    # HATA BURADAYDI: AsyncSession'da .query() kullanılmaz.
    # Yeni nesil asenkron sorgu yapısı:
    stmt = select(User).where(
        or_(
            User.id == (int(user_id) if str(user_id).isdigit() else -1), 
            User.email == str(user_id)
        )
    )
    result = await db.execute(stmt)
    user = result.scalars().first()
    
    return user

# ──────────────────────────────────────────────────────
# Şifre İşlemleri (Giriş Sorununu Çözdüğümüz Hali)
# ──────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    """Eski yapıya uygun 32 byte hex salt ile şifreleme."""
    salt = secrets.token_hex(32)
    digest = hashlib.sha256(f"{salt}{password}".encode("utf-8")).hexdigest()
    return f"{salt}${digest}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Eski hash'leri doğrulayabilen verify fonksiyonu."""
    try:
        if "$" not in hashed_password:
            return False
            
        salt, stored_digest = hashed_password.split("$", 1)
        computed_digest = hashlib.sha256(f"{salt}{plain_password}".encode("utf-8")).hexdigest()
        
        return secrets.compare_digest(computed_digest, stored_digest)
    except Exception as e:
        logger.error(f"Şifre doğrulama hatası: {e}")
        return False

# ──────────────────────────────────────────────────────
# JWT İşlemleri
# ──────────────────────────────────────────────────────

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def decode_access_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except Exception:
        return None