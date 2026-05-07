"""SmartDoz - Bakıcı ve Bildirim Yönetimi Router

POST   /caregivers               — Bakıcı ekle
GET    /caregivers               — Mevcut bakıcıları listele
DELETE /caregivers/{caregiver_id} — Bakıcıyı sil

GET    /list                     — Bildirimleri listele (sayfalanmış)
POST   /mark-read                — Bildirimleri okundu işaretle
"""
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import User, CaregiverRelationship, Notification, DoseLog, Medication
from schemas import (
    CaregiverCreate, CaregiverResponse, CaregiverUpdate,
    NotificationResponse, NotificationListResponse, NotificationMarkRead
)

router = APIRouter(prefix="/caregivers-notifications", tags=["Bakıcılar & Bildirimler"])


# ════════════════════════════════════════════════════════
# BAKICI YÖNETİMİ
# ════════════════════════════════════════════════════════

@router.post("/caregivers", response_model=CaregiverResponse, status_code=status.HTTP_201_CREATED)
async def add_caregiver(
    body: CaregiverCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Bakıcı ekle (ilişkili kişi) — email üzerinden.
    
    Örnek: Anne (current_user) kızını (caregiver_email) ekliyor.
    Kız, annesinin ilacı atladığında bildirim alacak.
    """
    # İlişkili kullanıcının var olduğunu doğrula (email ile)
    caregiver_user_res = await db.execute(
        select(User).where(User.email == body.caregiver_email)
    )
    caregiver_user = caregiver_user_res.scalar_one_or_none()
    if not caregiver_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Email {body.caregiver_email} ile kullanıcı bulunamadı.",
        )
    
    # Kendini bakıcı yapamaz
    if caregiver_user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kendini bakıcı olarak ekleyemezsin.",
        )
    
    # Aynı ilişki var mı diye kontrol et
    existing_res = await db.execute(
        select(CaregiverRelationship).where(
            and_(
                CaregiverRelationship.user_id == current_user.id,
                CaregiverRelationship.caregiver_user_id == caregiver_user.id,
            )
        )
    )
    if existing_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu ilişki zaten var.",
        )
    
    # Yeni ilişki oluştur
    caregiver_rel = CaregiverRelationship(
        user_id=current_user.id,
        caregiver_user_id=caregiver_user.id,
        relationship_type=body.relationship_type,
        is_active=True,
    )
    db.add(caregiver_rel)
    await db.commit()
    await db.refresh(caregiver_rel)
    
    return CaregiverResponse(
        id=caregiver_rel.id,
        user_id=caregiver_rel.user_id,
        caregiver_user_id=caregiver_rel.caregiver_user_id,
        caregiver_name=f"{caregiver_user.first_name} {caregiver_user.last_name}",
        caregiver_email=caregiver_user.email,
        relationship_type=caregiver_rel.relationship_type,
        is_active=caregiver_rel.is_active,
        created_at=caregiver_rel.created_at,
    )


@router.get("/caregivers", response_model=List[CaregiverResponse])
async def list_caregivers(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının mevcut bakıcılarını listele.
    
    Örnek: Anne kızını gördüğü bakıcıların listesi.
    """
    rels_res = await db.execute(
        select(CaregiverRelationship).where(
            CaregiverRelationship.user_id == current_user.id
        )
    )
    relationships = rels_res.scalars().all()
    
    result = []
    for rel in relationships:
        caregiver_res = await db.execute(
            select(User).where(User.id == rel.caregiver_user_id)
        )
        caregiver_user = caregiver_res.scalar_one_or_none()
        if caregiver_user:
            result.append(
                CaregiverResponse(
                    id=rel.id,
                    user_id=rel.user_id,
                    caregiver_user_id=rel.caregiver_user_id,
                    caregiver_name=f"{caregiver_user.first_name} {caregiver_user.last_name}",
                    caregiver_email=caregiver_user.email,
                    relationship_type=rel.relationship_type,
                    is_active=rel.is_active,
                    created_at=rel.created_at,
                )
            )
    
    return result


@router.delete("/caregivers/{caregiver_rel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_caregiver(
    caregiver_rel_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Bakıcıyı sil (ilişkiyi sonlandır).
    
    Örnek: Anne kızını bakıcılar listesinden çıkarıyor.
    """
    # İlişkiyi getir
    rel_res = await db.execute(
        select(CaregiverRelationship).where(
            and_(
                CaregiverRelationship.id == caregiver_rel_id,
                CaregiverRelationship.user_id == current_user.id,
            )
        )
    )
    rel = rel_res.scalar_one_or_none()
    if not rel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlişki bulunamadı.",
        )
    
    await db.delete(rel)
    await db.commit()


@router.patch("/caregivers/{caregiver_rel_id}", response_model=CaregiverResponse)
async def update_caregiver(
    caregiver_rel_id: int,
    body: CaregiverUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Bakıcı ilişkisini güncelle (aktif/pasif, ilişki tipi).
    """
    # İlişkiyi getir
    rel_res = await db.execute(
        select(CaregiverRelationship).where(
            and_(
                CaregiverRelationship.id == caregiver_rel_id,
                CaregiverRelationship.user_id == current_user.id,
            )
        )
    )
    rel = rel_res.scalar_one_or_none()
    if not rel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlişki bulunamadı.",
        )
    
    # Güncelle
    if body.is_active is not None:
        rel.is_active = body.is_active
    if body.relationship_type is not None:
        rel.relationship_type = body.relationship_type
    
    await db.commit()
    await db.refresh(rel)
    
    # Bakıcı bilgisini getir
    caregiver_res = await db.execute(
        select(User).where(User.id == rel.caregiver_user_id)
    )
    caregiver_user = caregiver_res.scalar_one_or_none()
    
    return CaregiverResponse(
        id=rel.id,
        user_id=rel.user_id,
        caregiver_user_id=rel.caregiver_user_id,
        caregiver_name=f"{caregiver_user.first_name} {caregiver_user.last_name}",
        caregiver_email=caregiver_user.email,
        relationship_type=rel.relationship_type,
        is_active=rel.is_active,
        created_at=rel.created_at,
    )


# ════════════════════════════════════════════════════════
# BİLDİRİM YÖNETİMİ
# ════════════════════════════════════════════════════════

@router.get("/list", response_model=NotificationListResponse)
async def get_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    unread_only: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Bildirim listesi al (sayfalanmış).
    
    Parametreler:
        skip: Kaç tane atlansın
        limit: Kaç tane getirilsin
        unread_only: Sadece okunmamış bildirimler mi
    
    Yanıt:
        total: Toplam bildirim sayısı (filter'den sonra)
        unread_count: Okunmamış bildirim sayısı
        notifications: Bildirim listesi (sayfalanmış)
    """
    # Toplam bildirim sayısı (caregiver'a gelen)
    query_total = select(func.count(Notification.id)).where(
        Notification.caregiver_id == current_user.id
    )
    
    if unread_only:
        query_total = query_total.where(Notification.is_read == False)
    
    total_res = await db.execute(query_total)
    total = total_res.scalar() or 0
    
    # Okunmamış bildirim sayısı
    unread_res = await db.execute(
        select(func.count(Notification.id)).where(
            and_(
                Notification.caregiver_id == current_user.id,
                Notification.is_read == False,
            )
        )
    )
    unread_count = unread_res.scalar() or 0
    
    # Bildirim listesi al (sayfalanmış)
    query = select(Notification).where(
        Notification.caregiver_id == current_user.id
    )
    
    if unread_only:
        query = query.where(Notification.is_read == False)
    
    # En yeni bildirimleri önce göster
    query = query.order_by(Notification.created_at.desc())
    query = query.offset(skip).limit(limit)
    
    notifs_res = await db.execute(query)
    notifications = notifs_res.scalars().all()
    
    # Enrichment: Kullanıcı adı ve ilaç adı ekle
    result_notifs = []
    for notif in notifications:
        user_res = await db.execute(
            select(User).where(User.id == notif.user_id)
        )
        user = user_res.scalar_one_or_none()
        user_name = f"{user.first_name} {user.last_name}" if user else None
        
        med_name = None
        if notif.medication_id:
            med_res = await db.execute(
                select(Medication).where(Medication.id == notif.medication_id)
            )
            med = med_res.scalar_one_or_none()
            med_name = med.name if med else None
        
        result_notifs.append(
            NotificationResponse(
                id=notif.id,
                user_id=notif.user_id,
                user_name=user_name,
                caregiver_id=notif.caregiver_id,
                dose_log_id=notif.dose_log_id,
                medication_id=notif.medication_id,
                medication_name=med_name,
                notification_type=notif.notification_type,
                title=notif.title,
                message=notif.message,
                is_read=notif.is_read,
                read_at=notif.read_at,
                created_at=notif.created_at,
            )
        )
    
    return NotificationListResponse(
        total=total,
        unread_count=unread_count,
        notifications=result_notifs,
    )


@router.post("/mark-read", status_code=status.HTTP_200_OK)
async def mark_notifications_read(
    body: NotificationMarkRead,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Bildirimleri okundu işaretle.
    
    İstek:
        notification_ids: Okundu işaretlenecek bildirim ID'leri
    
    Yanıt:
        updated_count: Güncellenen bildirim sayısı
    """
    # Bildirimleri al (current_user'a ait olanlarını kontrol et)
    notifs_res = await db.execute(
        select(Notification).where(
            and_(
                Notification.id.in_(body.notification_ids),
                Notification.caregiver_id == current_user.id,
            )
        )
    )
    notifications = notifs_res.scalars().all()
    
    if not notifications:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bildirimlerin hiçbiri bulunamadı.",
        )
    
    # Tümünü okundu işaretle
    updated_count = 0
    for notif in notifications:
        if not notif.is_read:
            notif.is_read = True
            notif.read_at = datetime.utcnow()
            updated_count += 1
    
    await db.commit()
    
    return {"updated_count": updated_count, "message": "Bildirimler okundu işaretlendi."}


# ════════════════════════════════════════════════════════
# SERVİS FONKSİYONU: Bildirim Gönder
# ════════════════════════════════════════════════════════

async def send_notification_to_caregivers(
    db: AsyncSession,
    user_id: int,
    notification_type: str,
    title: str,
    message: str,
    dose_log_id: int = None,
    medication_id: int = None,
):
    """
    Kullanıcının bakıcılarına bildirim gönder.
    
    Kullanım (dose_logs.py'de):
        await send_notification_to_caregivers(
            db, current_user.id,
            notification_type="MISSED_DOSE",
            title="İlaç Atlandı",
            message=f"{medication.name} saat {log.scheduled_time.strftime('%H:%M')}'de alınmadı.",
            dose_log_id=log.id,
            medication_id=medication.id,
        )
    """
    # Aktif bakıcıları getir
    caregivers_res = await db.execute(
        select(CaregiverRelationship).where(
            and_(
                CaregiverRelationship.user_id == user_id,
                CaregiverRelationship.is_active == True,
            )
        )
    )
    caregivers = caregivers_res.scalars().all()
    
    if not caregivers:
        return 0
    
    # Her bakıcı için bildirim oluştur
    created_count = 0
    for caregiver_rel in caregivers:
        notification = Notification(
            user_id=user_id,
            caregiver_id=caregiver_rel.caregiver_user_id,
            dose_log_id=dose_log_id,
            medication_id=medication_id,
            notification_type=notification_type,
            title=title,
            message=message,
            is_read=False,
        )
        db.add(notification)
        created_count += 1
    
    await db.commit()
    return created_count
