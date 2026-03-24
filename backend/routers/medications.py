"""
SmartDoz - İlaç Yönetimi Router'ı

GET    /medications/       — Kullanıcının ilaçlarını listele
POST   /medications/       — Yeni ilaç ekle
PUT    /medications/{id}   — İlaç güncelle
DELETE /medications/{id}   — İlaç sil

Tüm endpoint'ler JWT ile korumalıdır.
"""
from datetime import date as dt_date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from auth import get_current_user
from database import get_db
from models import DoseLog, GlobalMedication, Medication, User
from schemas import (
    GlobalMedicationSearchResult,
    MedicationCreate,
    MedicationResponse,
    MedicationScheduleDoseResponse,
    MedicationScheduleResponse,
    MedicationUpdate,
)
from services.scheduler import (
    create_future_dose_logs_for_medication,
    generate_schedule_for_medication_on_date,
)

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
    """Kullanıcıya yeni ilaç ekler ve 30 günlük planlanan dozları hazırlar."""
    new_med = Medication(
        user_id=current_user.id,
        **medication_data.model_dump(),
    )
    db.add(new_med)
    await db.commit()
    await db.refresh(new_med)

    # Modül 2 veri senkronizasyonu: takvimin boş kalmaması için 30 gün seed edilir.
    await create_future_dose_logs_for_medication(new_med.id, db, days=30)

    return new_med


@router.get(
    "/schedule/{date_str}",
    response_model=MedicationScheduleResponse,
    summary="Seçilen güne ait doz planı (geçmiş/bugün/gelecek)",
)
async def get_medication_schedule_by_date(
    date_str: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Evrensel doz sorgulama:
      - Geçmiş gün: yalnızca gerçek loglar (Alındı/Atlandı/Ertelendi)
      - Bugün: DB'deki gerçek günlük loglar
      - Gelecek: Algoritma 1 ile sanal Planlandı dozları
    """
    try:
        target = dt_date.fromisoformat(date_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz tarih formatı. YYYY-MM-DD kullanın.",
        )

    meds_res = await db.execute(
        select(Medication)
        .where(Medication.user_id == current_user.id)
        .order_by(Medication.name)
    )
    medications = meds_res.scalars().all()
    if not medications:
        return MedicationScheduleResponse(date=date_str, mode="today", dose_logs=[])

    med_map = {m.id: m for m in medications}
    med_ids = list(med_map.keys())
    today = dt_date.today()

    day_start = datetime.combine(target, datetime.min.time())
    day_end = datetime.combine(target, datetime.max.time())

    if target < today:
        # Geçmiş: sadece kullanıcı aksiyonunu temsil eden gerçek loglar.
        logs_res = await db.execute(
            select(DoseLog)
            .where(
                DoseLog.medication_id.in_(med_ids),
                DoseLog.scheduled_time >= day_start,
                DoseLog.scheduled_time <= day_end,
                DoseLog.status.in_(["Alındı", "Atlandı", "Ertelendi"]),
            )
            .order_by(DoseLog.scheduled_time)
        )
        logs = logs_res.scalars().all()
        dose_logs = [
            MedicationScheduleDoseResponse(
                id=log.id,
                medication_id=log.medication_id,
                medication_name=med_map[log.medication_id].name,
                dosage_form=med_map[log.medication_id].dosage_form,
                scheduled_time=log.scheduled_time,
                actual_time=log.actual_time,
                status=log.status,
                notes=log.notes,
                is_virtual=False,
            )
            for log in logs
            if log.medication_id in med_map
        ]
        return MedicationScheduleResponse(date=date_str, mode="past", dose_logs=dose_logs)

    if target == today:
        logs_res = await db.execute(
            select(DoseLog)
            .where(
                DoseLog.medication_id.in_(med_ids),
                DoseLog.scheduled_time >= day_start,
                DoseLog.scheduled_time <= day_end,
            )
            .order_by(DoseLog.scheduled_time)
        )
        logs = logs_res.scalars().all()
        dose_logs = [
            MedicationScheduleDoseResponse(
                id=log.id,
                medication_id=log.medication_id,
                medication_name=med_map[log.medication_id].name,
                dosage_form=med_map[log.medication_id].dosage_form,
                scheduled_time=log.scheduled_time,
                actual_time=log.actual_time,
                status=log.status,
                notes=log.notes,
                is_virtual=False,
            )
            for log in logs
            if log.medication_id in med_map
        ]
        return MedicationScheduleResponse(date=date_str, mode="today", dose_logs=dose_logs)

    # Gelecek: sanal planlanmış dozları döndür (DB'ye yazmadan hesaplanır)
    virtual_rows: list[MedicationScheduleDoseResponse] = []
    for med in medications:
        dose_times = await generate_schedule_for_medication_on_date(med, db, target)
        for dt in dose_times:
            synthetic_id = -int(f"{med.id}{dt.strftime('%d%H%M')}")
            virtual_rows.append(
                MedicationScheduleDoseResponse(
                    id=synthetic_id,
                    medication_id=med.id,
                    medication_name=med.name,
                    dosage_form=med.dosage_form,
                    scheduled_time=dt,
                    actual_time=None,
                    status="Planlandı",
                    notes="Henüz vakti gelmedi",
                    is_virtual=True,
                )
            )

    virtual_rows.sort(key=lambda x: x.scheduled_time)
    return MedicationScheduleResponse(date=date_str, mode="future", dose_logs=virtual_rows)


@router.get(
    "/global-search",
    response_model=List[GlobalMedicationSearchResult],
    summary="Global ilaç veritabanında ara (TypeAhead)",
)
async def search_global_medications(
    query: str,
    limit: int = 20,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    ILIKE tabanlı ilaç adı / etkin madde / ATC kodu araması.
    TypeAhead + sonsuz kaydırma için limit/offset destekler.
    En fazla 20 sonuç döner (limit parametresiyle kontrol edilir).
    """
    q = query.strip()
    if len(q) < 2:
        return []
    pattern = f"%{q}%"
    safe_limit = min(max(int(limit), 1), 50)  # 1-50 arasında zorla
    safe_offset = max(int(offset), 0)
    result = await db.execute(
        select(GlobalMedication)
        .where(
            or_(
                GlobalMedication.product_name.ilike(pattern),
                GlobalMedication.active_ingredient.ilike(pattern),
                GlobalMedication.atc_code.ilike(pattern),
            )
        )
        .order_by(GlobalMedication.product_name)
        .limit(safe_limit)
        .offset(safe_offset)
    )
    return result.scalars().all()


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
