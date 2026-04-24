from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
import logging

# Kendi modüllerinden importlar (Dosya yollarını kontrol et)
from core.security import decode_access_token, security 
from database import get_db
from models import User

logger = logging.getLogger(__name__)

async def get_current_user(
    token_obj = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik doğrulaması başarısız.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not token_obj:
        raise credentials_exception

    token = token_obj.credentials
    payload = decode_access_token(token)
    
    if not payload or not isinstance(payload, dict):
        raise credentials_exception
        
    # BURASI KRİTİK: 'sub' içinden gelen veriyi string (email) olarak alıyoruz
    user_identity = payload.get("sub")
    if user_identity is None:
        raise credentials_exception

    try:
        # Sorguyu hem ID hem de Email kontrolü yapacak şekilde esnetiyoruz
        # Böylece içinden ne çıkarsa çıksın (ID mi email mi) kullanıcıyı bulur.
        if "@" in str(user_identity):
            # Eğer içinde @ varsa email'dir
            result = await db.execute(select(User).filter(User.email == str(user_identity)))
        else:
            # Değilse ID'dir
            result = await db.execute(select(User).filter(User.id == int(user_identity)))
            
        user = result.scalar_one_or_none()
        
        if user is None:
            logger.warning(f"⚠️ Kullanıcı bulunamadı: {user_identity}")
            raise credentials_exception
            
        return user

    except Exception as e:
        logger.error(f"❌ Kullanıcı sorgulama hatası: {e}")
        raise credentials_exception