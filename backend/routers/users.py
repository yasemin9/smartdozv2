"""
SmartDoz - Kimlik Doğrulama Router'ı

POST /auth/register  — Yeni hesap oluşturma
POST /auth/login     — E-posta + şifre ile JWT token alma
GET  /auth/me        — Oturumdaki kullanıcı bilgisi
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from core.security import create_access_token, hash_password, verify_password
from database import get_db
from models import User
from schemas import Token, UserCreate, UserLogin, UserResponse

router = APIRouter(prefix="/auth", tags=["Kimlik Doğrulama"])


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Yeni kullanıcı kaydı",
)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    """
    Yeni kullanıcı hesabı oluşturur.
    E-posta zaten kayıtlıysa 400 döner.
    """
    result = await db.execute(select(User).where(User.email == user_data.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu e-posta adresi zaten kayıtlı.",
        )

    new_user = User(
        first_name=user_data.first_name.strip(),
        last_name=user_data.last_name.strip(),
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user


@router.post(
    "/login",
    response_model=Token,
    summary="Kullanıcı girişi",
)
async def login(credentials: UserLogin, db: AsyncSession = Depends(get_db)):
    """
    E-posta ve şifre ile doğrulama yapar; başarılıysa JWT token döner.
    Hatalı kimlik bilgileri için güvenlik nedeniyle genel hata mesajı verilir.
    """
    result = await db.execute(select(User).where(User.email == credentials.email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta veya şifre hatalı.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": user.email})
    return Token(access_token=access_token)


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Oturumdaki kullanıcı bilgisi",
)
async def get_me(current_user: User = Depends(get_current_user)):
    """Geçerli access token'a ait kullanıcı bilgisini döner."""
    return current_user
