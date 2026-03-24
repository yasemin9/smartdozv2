"""SmartDoz - Kullanıcı Tercihleri Router

GET /preferences   — Uyanma / uyuma saatlerini döner
PUT /preferences   — Günceller (upsert)

Bu tercihler ZAMANDILIMIHESAPLA algoritmasının girdi parametrelerini
belirler (EK1_revize.pdf, Sayfa 37).
"""
from datetime import time

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import User, UserPreference
from schemas import UserPreferenceResponse, UserPreferenceUpdate

router = APIRouter(prefix="/preferences", tags=["Tercihler"])


@router.get("/", response_model=UserPreferenceResponse)
async def get_preferences(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının uyanma / uyuma tercihlerini döner. Kayıt yoksa varsayılanlar."""
    result = await db.execute(
        select(UserPreference).where(UserPreference.user_id == current_user.id)
    )
    pref = result.scalar_one_or_none()
    if pref is None:
        return UserPreferenceResponse(wake_time=time(8, 0), sleep_time=time(22, 0))
    return pref


@router.put("/", response_model=UserPreferenceResponse)
async def update_preferences(
    body: UserPreferenceUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Uyanma / uyuma saatlerini günceller (kayıt yoksa oluşturur)."""
    result = await db.execute(
        select(UserPreference).where(UserPreference.user_id == current_user.id)
    )
    pref = result.scalar_one_or_none()

    if pref is None:
        pref = UserPreference(
            user_id=current_user.id,
            wake_time=body.wake_time,
            sleep_time=body.sleep_time,
        )
        db.add(pref)
    else:
        pref.wake_time  = body.wake_time
        pref.sleep_time = body.sleep_time

    await db.commit()
    await db.refresh(pref)
    return pref
