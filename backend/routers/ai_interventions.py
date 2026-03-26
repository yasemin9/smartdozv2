"""
SmartDoz - Modül 8: YZ Destekli Akıllı Özellikler Router

Endpoint'ler:
    GET  /ai/profile               — Kişisel profil + bekleyen kararlar
    POST /ai/decisions/generate    — Yeni YZ kararları üret (veya mevcut getir)
    GET  /ai/decisions/pending     — Bekleyen kararları listele
    GET  /ai/decisions/recent      — Son çözümlenmiş kararları listele
    POST /ai/decisions/{id}/resolve — Kullanıcı onayla/reddet
    GET  /ai/tips                  — Metin tabanlı akıllı ipuçları (hiçbir otomatik eylem yok)
"""
import json
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import AIDecision, Medication, User
from schemas import (
    AIDecisionResponse,
    AIDecisionResolve,
    AIProfileResponse,
    BehaviorProfile,
    SmartTipResponse,
    TimeWindowScore,
)
from services.decision_engine import decision_engine

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Modül 8 — YZ Akıllı Özellikler"])


# ──────────────────────────────────────────────────────
# Yardımcı: ORM → Response dönüştürücü
# ──────────────────────────────────────────────────────

async def _ai_decision_to_response(
    decision: AIDecision,
    db: AsyncSession,
) -> AIDecisionResponse:
    """AIDecision ORM nesnesini Pydantic yanıt modeline dönüştürür."""
    med_name: Optional[str] = None
    if decision.medication_id is not None:
        stmt = select(Medication).where(Medication.id == decision.medication_id)
        result = await db.execute(stmt)
        med = result.scalars().first()
        med_name = med.name if med else None

    payload_dict: Optional[dict] = None
    if decision.payload:
        try:
            payload_dict = json.loads(decision.payload)
        except (json.JSONDecodeError, TypeError):
            payload_dict = None

    return AIDecisionResponse(
        id=decision.id,
        medication_id=decision.medication_id,
        medication_name=med_name,
        decision_type=decision.decision_type,
        time_window=decision.time_window,
        explanation=decision.explanation,
        payload=payload_dict,
        status=decision.status,
        outcome=decision.outcome,
        created_at=decision.created_at,
        resolved_at=decision.resolved_at,
    )


# ──────────────────────────────────────────────────────
# Endpoint: Kişisel Profil (F-M8.1)
# ──────────────────────────────────────────────────────

@router.get(
    "/profile",
    response_model=AIProfileResponse,
    summary="[F-M8.1] Kullanıcının YZ davranış profili ve bekleyen kararlar",
)
async def get_ai_profile(
    days: int = 30,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının son ``days`` günlük davranış profilini,
    lokal pencere skorlarını ve bekleyen YZ kararlarını döner.

    Bu endpoint dashboard için ana veri kaynağıdır.
    """
    # Süresi dolan kararları temizle
    await decision_engine.expire_stale_decisions(current_user.id, db)

    # Profil analizi
    profile_result = await decision_engine.analyze_user(
        user_id=current_user.id,
        db=db,
        days=days,
    )

    # Bekleyen ve son kararlar
    pending_raw = await decision_engine.get_pending_decisions(current_user.id, db)
    recent_raw  = await decision_engine.get_recent_decisions(current_user.id, db, limit=5)

    pending_resp = [await _ai_decision_to_response(d, db) for d in pending_raw]
    recent_resp  = [await _ai_decision_to_response(d, db) for d in recent_raw]

    # Profil yanıtı inşası
    window_scores = [
        TimeWindowScore(
            window=w.window,
            label=w.label,
            planned=w.planned,
            taken=w.taken,
            local_score=w.local_score,
            consecutive_skips=w.consecutive_skips,
        )
        for w in profile_result.window_analyses
    ]

    behavior_profile = BehaviorProfile(
        profile_type=profile_result.profile_type,
        profile_icon=profile_result.profile_icon,
        description=profile_result.description,
        overall_score=profile_result.overall_score,
        window_scores=window_scores,
    )

    await db.commit()
    return AIProfileResponse(
        behavior_profile=behavior_profile,
        pending_decisions=pending_resp,
        recent_decisions=recent_resp,
    )


# ──────────────────────────────────────────────────────
# Endpoint: Karar Üret (F-M8.2 + F-M8.3 + F-M8.4)
# ──────────────────────────────────────────────────────

@router.post(
    "/decisions/generate",
    response_model=list[AIDecisionResponse],
    status_code=status.HTTP_201_CREATED,
    summary="[F-M8.2/3/4] Kullanıcı için yeni YZ kararları üret",
)
async def generate_decisions(
    days: int = 30,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Algoritma 5'i çalıştırır ve yeni YZ kararları üretir.

    - Zaten aktif PENDING karar varsa tekrar oluşturmaz (idempotent).
    - Klinik risk varsa → DOCTOR_REFERRAL, saat değişikliği yok.
    - Sistematik sapma varsa → SCHEDULE_SHIFT önerisi.
    - Yüksek/düşük uyum → TONE_ADAPT önerisi.
    - 48 saati geçen eski PENDING kararlar EXPIRED olarak işaretlenir.
    """
    await decision_engine.expire_stale_decisions(current_user.id, db)
    await decision_engine.generate_decisions(
        user_id=current_user.id,
        db=db,
        days=days,
    )
    await db.commit()

    # commit() sonrası SQLAlchemy nesneleri "expired" olur; doğrudan attribute
    # erişimi yerine DB'den taze sorgulama yap (lazy-load sorununu önler).
    pending = await decision_engine.get_pending_decisions(current_user.id, db)
    logger.info(
        "generate_decisions: user=%d → %d PENDING karar döndürüldü",
        current_user.id, len(pending),
    )
    return [await _ai_decision_to_response(d, db) for d in pending]


# ──────────────────────────────────────────────────────
# Endpoint: Bekleyen Kararlar
# ──────────────────────────────────────────────────────

@router.get(
    "/decisions/pending",
    response_model=list[AIDecisionResponse],
    summary="Kullanıcının bekleyen (PENDING) YZ kararlarını listele",
)
async def list_pending_decisions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Onay/ret bekleyen tüm YZ kararlarını döner."""
    await decision_engine.expire_stale_decisions(current_user.id, db)
    await db.commit()

    decisions = await decision_engine.get_pending_decisions(current_user.id, db)
    return [await _ai_decision_to_response(d, db) for d in decisions]


# ──────────────────────────────────────────────────────
# Endpoint: Son Kararlar
# ──────────────────────────────────────────────────────

@router.get(
    "/decisions/recent",
    response_model=list[AIDecisionResponse],
    summary="Son çözümlenmiş YZ kararlarını listele",
)
async def list_recent_decisions(
    limit: int = 10,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """APPROVED / REJECTED / EXPIRED kararlarını döner."""
    decisions = await decision_engine.get_recent_decisions(
        current_user.id, db, limit=limit
    )
    return [await _ai_decision_to_response(d, db) for d in decisions]


# ──────────────────────────────────────────────────────
# Endpoint: Karar Onayla / Reddet (F-M8.4)
# ──────────────────────────────────────────────────────

@router.post(
    "/decisions/{decision_id}/resolve",
    response_model=AIDecisionResponse,
    summary="[F-M8.4] Kullanıcı bir YZ kararını onayla veya reddet",
)
async def resolve_decision(
    decision_id: int,
    body: AIDecisionResolve,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının onay/ret kararını kaydeder.

    - **APPROVED**: Kapalı döngü takip başlatılır (±7 gün).
    - **REJECTED**: Karar arşivlenir.

    Sadece sahibi olan kullanıcı kendi kararı üzerinde işlem yapabilir.
    Başka bir kullanıcının kararına erişim girişimi 404 döner.
    """
    try:
        decision = await decision_engine.resolve_decision(
            decision_id=decision_id,
            user_id=current_user.id,
            new_status=body.status,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )

    await db.commit()
    return await _ai_decision_to_response(decision, db)


# ──────────────────────────────────────────────────────
# Endpoint: Akıllı İpucu Kartları (F-M8 Sadece Öneri)
# ──────────────────────────────────────────────────────

@router.get(
    "/tips",
    response_model=list[SmartTipResponse],
    summary="[F-M8] Metin tabanlı akıllı ipucu kartlarını getir",
)
async def get_smart_tips(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Algoritma 5 çıktılarını kullanarak yalnızca metin tabanlı ipucu
    kartları döner. Sistem hiçbir otomatik değişiklik yapmaz;
    tüm kararlar kullanıcıya bırakılır (XAI prensibi dahil).

    - ``days``: Kaç günlük log analiz edilsin (varsayılan 7).
    """
    raw_tips = await decision_engine.generate_smart_tips(
        user_id=current_user.id,
        db=db,
        days=days,
    )
    return [
        SmartTipResponse(
            tip_id=t["tip_id"],
            icon=t["icon"],
            title=t["title"],
            message=t["message"],
            xai_reason=t["xai_reason"],
            tip_type=t["tip_type"],
        )
        for t in raw_tips
    ]
