"""
SmartDoz - Modül 3: İlaç Etkileşim Router'ı

POST /interactions/check-interaction
    — Yeni ilacı mevcut liste ile karşılaştırır
    — ATC kodu ile etken madde eşlemesi (Algoritma 2)
    — Levenshtein mesafe fallback (Algoritma 3)
    — Risk seviyesine göre sıralanmış sonuçlar
"""
from __future__ import annotations

import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import User
from schemas import (
    DrugInfo,
    InteractionCheckRequest,
    InteractionCheckResponse,
    InteractionResult,
)
from services.interaction_engine import interaction_engine, translate_to_turkish

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/interactions", tags=["Modül 3 — Etkileşim"])

# Risk seviyesi sıralama önceliği
_RISK_PRIORITY = {"YUKSEK": 0, "ORTA": 1, "DUSUK": 2}


# ──────────────────────────────────────────────────────────────────────────────
# Yardımcı: ATC → etken madde zinciri
# ──────────────────────────────────────────────────────────────────────────────

async def _resolve_ingredient(drug: DrugInfo, db: AsyncSession) -> Optional[str]:
    """
    Bir DrugInfo'dan etken madde adını çözer.

    Zincir:
      1. drug.active_ingredient               — direkt değer varsa kullan
      2. drug.atc_code → global_medications   — ATC ile katalogdan bul
      3. drug.name → global_medications       — ürün adı ile katalogdan bul
      4. drug.name                            — son çare (jenerik İngilizce isimler)
    """
    # 1. Direkt etken madde
    if drug.active_ingredient and drug.active_ingredient.strip():
        return drug.active_ingredient.strip()

    # 2. ATC kodu ile katalog araması — ATC dil bağımsız primary key gibi davranır
    if drug.atc_code and drug.atc_code.strip():
        try:
            res = await db.execute(
                text(
                    "SELECT active_ingredient FROM global_medications "
                    "WHERE LOWER(atc_code) = LOWER(:atc) "
                    "AND active_ingredient IS NOT NULL AND active_ingredient != '' "
                    "LIMIT 1"
                ),
                {"atc": drug.atc_code.strip()},
            )
            found = res.scalar_one_or_none()
            if found and found.strip():
                return found.strip()
        except Exception as exc:
            logger.warning(f"ATC lookup hatası ({drug.atc_code}): {exc}")

    # 3. Ürün adı ile katalog araması
    if drug.name and drug.name.strip():
        name = drug.name.strip()
        first_word = name.split()[0]

        try:
            # 3a. İlk kelime ile ILIKE + similarity sıralama
            if len(first_word) >= 4:
                res2 = await db.execute(
                    text(
                        "SELECT active_ingredient FROM global_medications "
                        "WHERE product_name ILIKE :pattern "
                        "AND active_ingredient IS NOT NULL AND active_ingredient != '' "
                        "ORDER BY similarity(LOWER(product_name), LOWER(:name)) DESC "
                        "LIMIT 1"
                    ),
                    {"pattern": f"%{first_word}%", "name": name},
                )
                found2 = res2.scalar_one_or_none()
                if found2 and found2.strip():
                    return found2.strip()

            # 3b. pg_trgm benzerlik araması (geniş ağ)
            res3 = await db.execute(
                text(
                    "SELECT active_ingredient FROM global_medications "
                    "WHERE similarity(LOWER(product_name), LOWER(:n)) > 0.35 "
                    "AND active_ingredient IS NOT NULL AND active_ingredient != '' "
                    "ORDER BY similarity(LOWER(product_name), LOWER(:n)) DESC "
                    "LIMIT 1"
                ),
                {"n": name},
            )
            found3 = res3.scalar_one_or_none()
            if found3 and found3.strip():
                return found3.strip()

        except Exception as exc:
            logger.warning(f"Ürün adı lookup hatası ({name}): {exc}")

        # 4. Son çare: ilaç adını direkt kullan
        return name

    return None


# ──────────────────────────────────────────────────────────────────────────────
# Endpoint
# ──────────────────────────────────────────────────────────────────────────────

@router.post(
    "/check-interaction",
    response_model=InteractionCheckResponse,
    summary="Algoritma 2 & 3 — Kapsamlı ilaç etkileşim kontrolü",
    description=(
        "Yeni ilacı mevcut ilaç listesiyle karşılaştırır. "
        "ATC kodu ile etken madde eşlemesi yapılır (Algoritma 2). "
        "Eşleşme bulunamazsa Levenshtein mesafe fallback devreye girer (Algoritma 3). "
        "YUKSEK riskli etkileşimler yanıtın başında yer alır."
    ),
)
async def check_interaction(
    request: InteractionCheckRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> InteractionCheckResponse:
    try:
        # Yeni ilaç için etken madde çöz
        new_ingredient = await _resolve_ingredient(request.new_drug, db)
        if not new_ingredient:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "Yeni ilaç için etken madde belirlenemedi. "
                    "Lütfen name, atc_code veya active_ingredient alanlarından en az birini doldurun."
                ),
            )

        if not interaction_engine.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Etkileşim motoru henüz hazır değil. Lütfen birkaç saniye sonra tekrar deneyin.",
            )

        results: list[InteractionResult] = []
        seen: set[str] = set()

        for existing_drug in request.existing_drugs:
            try:
                existing_ingredient = await _resolve_ingredient(existing_drug, db)
                if not existing_ingredient:
                    continue

                hit = interaction_engine.lookup(new_ingredient, existing_ingredient)
                if not hit:
                    continue

                # Tekrar eden sonuçları önle
                dedup_key = f"{existing_ingredient.lower()[:30]}|{hit['description'][:40]}"
                if dedup_key in seen:
                    continue
                seen.add(dedup_key)

                results.append(
                    InteractionResult(
                        with_drug_name=existing_drug.name or existing_ingredient,
                        risk_level=hit["risk_level"],
                        description=translate_to_turkish(hit["description"]),
                        matched_by=hit["matched_by"],
                        confidence_score=hit["confidence_score"],
                    )
                )

            except Exception as exc:
                # Tek bir ilaç hatası tüm kontrolü durdurmasın
                logger.warning(
                    f"Etkileşim kontrolü sırasında ilaç atlandı "
                    f"({existing_drug.name}): {exc}"
                )
                continue

        # YUKSEK → ORTA → DUSUK sıralanır
        results.sort(key=lambda r: _RISK_PRIORITY.get(r.risk_level, 1))

        return InteractionCheckResponse(
            new_drug_name=request.new_drug.name or new_ingredient,
            resolved_ingredient=new_ingredient,
            interactions=results,
            has_high_risk=any(r.risk_level == "YUKSEK" for r in results),
        )

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(f"check_interaction beklenmeyen hata: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Etkileşim kontrolü sırasında beklenmeyen hata oluştu.",
        )
