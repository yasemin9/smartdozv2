"""
SmartDoz - İlaç Yönetimi Router'ı

GET    /medications/       — Kullanıcının ilaçlarını listele
POST   /medications/       — Yeni ilaç ekle
PUT    /medications/{id}   — İlaç güncelle
DELETE /medications/{id}   — İlaç sil

Tüm endpoint'ler JWT ile korumalıdır.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from auth import get_current_user
from database import get_db
from models import Medication, User
from schemas import MedicationCreate, MedicationResponse, MedicationUpdate
from services.scheduler import create_dose_logs_for_medication

router = APIRouter(prefix="/medications", tags=["İlaçlar"])


@router.get(
    "/",
    response_model=List[MedicationResponse],
    summary="Kullanıcının ilaç listesi",
)
async def list_medications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Oturumdaki kullanıcıya ait tüm ilaçları döner."""
    result = await db.execute(
        select(Medication)
        .where(Medication.user_id == current_user.id)
        .order_by(Medication.expiry_date)
    )
    return result.scalars().all()


@router.post(
    "/",
    response_model=MedicationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Yeni ilaç ekle",
)
async def create_medication(
    medication_data: MedicationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcıya yeni bir ilaç kaydı ekler ve bugüne ait doz loglarını anlık oluşturur."""
    new_med = Medication(
        user_id=current_user.id,
        **medication_data.model_dump(),
    )
    db.add(new_med)
    await db.commit()
    await db.refresh(new_med)

    # Algoritma 1 (EK1_revize.pdf s.37): bugünün dozlarını hemen DB'ye yaz
    await create_dose_logs_for_medication(new_med.id, db)

    return new_med


@router.put(
    "/{medication_id}",
    response_model=MedicationResponse,
    summary="İlaç güncelle",
)
async def update_medication(
    medication_id: int,
    medication_data: MedicationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Belirtilen ilaç kaydını günceller. Kayıt kullanıcıya ait değilse 404 döner."""
    result = await db.execute(
        select(Medication).where(
            Medication.id == medication_id,
            Medication.user_id == current_user.id,
        )
    )
    medication = result.scalar_one_or_none()
    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlaç bulunamadı.",
        )

    for field, value in medication_data.model_dump(exclude_unset=True).items():
        setattr(medication, field, value)

    await db.commit()
    await db.refresh(medication)
    return medication


@router.delete(
    "/{medication_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="İlaç sil",
)
async def delete_medication(
    medication_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Belirtilen ilaç kaydını siler. Kayıt kullanıcıya ait değilse 404 döner."""
    result = await db.execute(
        select(Medication).where(
            Medication.id == medication_id,
            Medication.user_id == current_user.id,
        )
    )
    medication = result.scalar_one_or_none()
    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlaç bulunamadı.",
        )

    await db.delete(medication)
    await db.commit()
