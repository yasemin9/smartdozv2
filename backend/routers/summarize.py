"""
SmartDoz - Modül 5: İlaç Bilgisi Özetleme Router'ı

GET /summarize/medication/{medication_id}
    — Kullanıcının ilacını ID ile özetler (JWT korumalı)

GET /summarize/global/{global_med_id}
    — Global ilaç kataloğundan ID ile özetler (JWT korumalı)

POST /summarize/text
    — Ham metin göndererek özetleme yapar (geliştirici/test için)

Tüm endpoint'ler JWT ile korumalıdır.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional

from auth import get_current_user
from database import get_db
from models import GlobalMedication, Medication, User
from services.summarization_service import MedicationSummary, summarize_medication

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/summarize", tags=["Modül 5: İlaç Özetleme"])


# ──────────────────────────────────────────────────────────────────────────────
# Response / Request Şemaları
# ──────────────────────────────────────────────────────────────────────────────

class MedicationSummaryResponse(BaseModel):
    """İlaç özeti API yanıtı."""
    product_name: str
    active_ingredient: Optional[str] = None
    atc_code: Optional[str] = None
    category: Optional[str] = None

    # Eski bölüm bazlı alanlar (geriye dönük uyumluluk)
    indication: str
    side_effects: str
    dosage: str
    warnings: str

    dosage_entities: List[str] = Field(default_factory=list)
    critical_side_effects: List[str] = Field(default_factory=list)

    # ── Yeni 3-Kategori Yapılandırılmış Özet ─────────────────────────────────
    temel_faydasi: List[str] = Field(default_factory=list)
    kullanim_sekli: List[str] = Field(default_factory=list)
    dikkat_edilecekler: List[str] = Field(default_factory=list)

    summary_method: str
    disclaimer: str

    model_config = {"from_attributes": True}

    @classmethod
    def from_service(cls, s: MedicationSummary) -> "MedicationSummaryResponse":
        return cls(
            product_name=s.product_name,
            active_ingredient=s.active_ingredient,
            atc_code=s.atc_code,
            category=s.category,
            indication=s.indication,
            side_effects=s.side_effects,
            dosage=s.dosage,
            warnings=s.warnings,
            dosage_entities=s.dosage_entities,
            critical_side_effects=s.critical_side_effects,
            temel_faydasi=s.temel_faydasi,
            kullanim_sekli=s.kullanim_sekli,
            dikkat_edilecekler=s.dikkat_edilecekler,
            summary_method=s.summary_method,
            disclaimer=s.disclaimer,
        )


class TextSummarizeRequest(BaseModel):
    """Ham metin özetleme isteği."""
    product_name: str = Field(..., min_length=1, max_length=300)
    description: str = Field(..., min_length=50, max_length=50_000)
    active_ingredient: Optional[str] = Field(None, max_length=300)
    atc_code: Optional[str] = Field(None, max_length=20)
    category: Optional[str] = Field(None, max_length=200)
    use_transformers: bool = Field(
        default=True,
        description="True: Hugging Face modeli dene; False: sadece kural tabanlı",
    )


# ──────────────────────────────────────────────────────────────────────────────
# Endpoint 1: Kullanıcının kendi ilacını özetle
# ──────────────────────────────────────────────────────────────────────────────

@router.get(
    "/medication/{medication_id}",
    response_model=MedicationSummaryResponse,
    summary="Kullanıcının ilacını özetle",
    description=(
        "JWT ile oturum açılmış kullanıcının ilaç kaydını bulur. "
        "İlaç adına karşılık gelen prospektüs metnini global_medications "
        "tablosundan çeker ve yapay zeka ile özetler."
    ),
)
async def summarize_user_medication(
    medication_id: int,
    use_transformers: bool = True,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MedicationSummaryResponse:
    # Kullanıcının ilacı
    med_row = await db.execute(
        select(Medication).where(
            Medication.id == medication_id,
            Medication.user_id == current_user.id,
        )
    )
    medication = med_row.scalar_one_or_none()
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlaç bulunamadı veya bu ilaç size ait değil.",
        )

    # Global katalogdan prospektüs metnini bul
    # Önce ATC kodu ile eşleştir; yoksa ürün adına göre ara
    global_med = None
    if medication.atc_code:
        gm_row = await db.execute(
            select(GlobalMedication).where(
                GlobalMedication.atc_code == medication.atc_code
            ).limit(1)
        )
        global_med = gm_row.scalar_one_or_none()

    if global_med is None:
        # Ad benzerliği: ilacın ilk kelimesi
        name_prefix = medication.name.split()[0] if medication.name else ""
        if name_prefix:
            gm_row = await db.execute(
                select(GlobalMedication).where(
                    GlobalMedication.product_name.ilike(f"{name_prefix}%")
                ).limit(1)
            )
            global_med = gm_row.scalar_one_or_none()

    description = ""
    category = None
    global_active = medication.active_ingredient
    global_atc = medication.atc_code

    if global_med:
        description = global_med.description or ""
        category = _build_category(global_med)
        global_active = global_active or global_med.active_ingredient
        global_atc = global_atc or global_med.atc_code

    if not description:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"'{medication.name}' için prospektüs metni bulunamadı.",
        )

    summary = summarize_medication(
        product_name=medication.name,
        description=description,
        active_ingredient=global_active,
        atc_code=global_atc,
        category=category,
        use_transformers=use_transformers,
    )
    return MedicationSummaryResponse.from_service(summary)


# ──────────────────────────────────────────────────────────────────────────────
# Endpoint 2: Global katalogdan özetle
# ──────────────────────────────────────────────────────────────────────────────

@router.get(
    "/global/{global_med_id}",
    response_model=MedicationSummaryResponse,
    summary="Global katalog ilaç özetleme",
    description=(
        "Global ilaç kataloğundan (global_medications) ID'ye göre prospektüs çeker "
        "ve yapay zeka ile özetler. TypeAhead ile seçilen ilaçlar için kullanılır."
    ),
)
async def summarize_global_medication(
    global_med_id: int,
    use_transformers: bool = True,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> MedicationSummaryResponse:
    row = await db.execute(
        select(GlobalMedication).where(GlobalMedication.id == global_med_id)
    )
    global_med = row.scalar_one_or_none()
    if global_med is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Global ilaç kaydı bulunamadı.",
        )

    description = global_med.description or ""
    if not description or description.strip() in (
        "İkinci siteye ait içerik bulunamadı.",
        "",
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"'{global_med.product_name}' için prospektüs metni mevcut değil.",
        )

    summary = summarize_medication(
        product_name=global_med.product_name,
        description=description,
        active_ingredient=global_med.active_ingredient,
        atc_code=global_med.atc_code,
        category=_build_category(global_med),
        use_transformers=use_transformers,
    )
    return MedicationSummaryResponse.from_service(summary)


# ──────────────────────────────────────────────────────────────────────────────
# Endpoint 3: Ham metin özetleme (geliştirici/test)
# ──────────────────────────────────────────────────────────────────────────────

@router.post(
    "/text",
    response_model=MedicationSummaryResponse,
    summary="Ham metin özetleme",
    description=(
        "Kullanıcının veya sistemin gönderdiği ham prospektüs metni özetlenir. "
        "Geliştirme ve test amacıyla kullanılabilir."
    ),
)
async def summarize_raw_text(
    request: TextSummarizeRequest,
    _: User = Depends(get_current_user),
) -> MedicationSummaryResponse:
    summary = summarize_medication(
        product_name=request.product_name,
        description=request.description,
        active_ingredient=request.active_ingredient,
        atc_code=request.atc_code,
        category=request.category,
        use_transformers=request.use_transformers,
    )
    return MedicationSummaryResponse.from_service(summary)


# ──────────────────────────────────────────────────────────────────────────────
# Yardımcı
# ──────────────────────────────────────────────────────────────────────────────

def _build_category(gm: GlobalMedication) -> Optional[str]:
    """Kategori hiyerarşisini tek string'e dönüştürür."""
    parts = [
        gm.category_1, gm.category_2, gm.category_3, gm.category_4, gm.category_5
    ]
    filled = [p.strip(" /") for p in parts if p and p.strip()]
    return " › ".join(filled) if filled else None
