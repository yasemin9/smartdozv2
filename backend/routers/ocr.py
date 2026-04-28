"""
SmartDoz - Modül 4: OCR İlaç Tanıma Router'ı

POST /ocr/scan
    Görüntü dosyasını alır, OpenCV ile ön işler, Tesseract veya Google Vision
    ile metin çıkarır, Algoritma 3 (Levenshtein) ile DB'deki global ilaç listesiyle
    karşılaştırır ve %85 eşiğini geçen adayları döndürür.

Tüm endpoint'ler JWT ile korumalıdır.
"""
import logging

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import GlobalMedication, User
from schemas import OCRMatchCandidate, OCRScanResponse
from services.ocr_service import (
    GoogleVisionOCREngine,
    TesseractOCREngine,
    find_best_matches,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ocr", tags=["Modül 4 — OCR İlaç Tanıma"])

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


@router.post(
    "/scan",
    response_model=OCRScanResponse,
    summary="İlaç kutusu fotoğrafından ilaç adını otomatik tanı (Algoritma 3)",
    status_code=status.HTTP_200_OK,
)
async def scan_medication_image(
    file: UploadFile = File(description="İlaç kutusu görüntüsü (JPEG / PNG / WebP, maks. 10 MB)"),
    engine: str = Query(
        default="tesseract",
        description="OCR motoru: 'tesseract' (varsayılan) veya 'google_vision'",
    ),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OCRScanResponse:
    """
    **Modül 4 — OCR Destekli Otomatik İlaç Tanıma Akışı**

    1. Görüntü doğrulaması (tür ve boyut kontrolü)
    2. OpenCV ön işleme: RGB→Gray → Gaussian Blur → Otsu/Adaptive Threshold
    3. OCR metin çıkarma: Tesseract LSTM (`--oem 1 --psm 11`) veya Google Vision
    4. **Algoritma 3 — Levenshtein Düzenleme Uzaklığı**: OCR tokenleri ile
       `global_medications` tablosundaki tüm ürün adları karşılaştırılır.
       Benzerlik oranı **≥ %85** olan adaylar azalan sırada döndürülür.
    5. Kullanıcı Flutter arayüzünde en iyi eşleşmeyi onaylar.

    **Örnek gürültülü OCR senaryosu:**
    - Kutu üzerinde okunan → `"Par01 200mg"`
    - Levenshtein ile bulunan en yakın → `"PAROL 200 MG"` (similarity: 0.87)
    """
    # ── Dosya türü doğrulaması ──────────────────────────────────────────────
    content_type = (file.content_type or "").lower()
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=(
                f"Desteklenmeyen dosya türü: {content_type!r}. "
                "Yalnızca JPEG, PNG veya WebP kabul edilir."
            ),
        )

    # ── Boyut doğrulaması ──────────────────────────────────────────────────
    image_bytes = await file.read()
    if len(image_bytes) > _MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Görüntü boyutu 10 MB sınırını aşıyor.",
        )

    # ── OCR motoru seçimi ──────────────────────────────────────────────────
    if engine == "google_vision":
        ocr_engine = GoogleVisionOCREngine()
    else:
        ocr_engine = TesseractOCREngine()

    # ── Metin çıkarma ──────────────────────────────────────────────────────
    try:
        ocr_text = ocr_engine.extract_text(image_bytes)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    if not ocr_text.strip():
        logger.info("Kullanıcı %d: OCR boş metin döndürdü.", current_user.id)
        return OCRScanResponse(ocr_raw_text="", candidates=[])

    # ── Global ilaç listesini DB'den çek ──────────────────────────────────
    result = await db.execute(select(GlobalMedication.product_name))
    med_names: list[str] = [row[0] for row in result.fetchall()]

    if not med_names:
        logger.warning("global_medications tablosu boş — Levenshtein atlanıyor.")
        return OCRScanResponse(ocr_raw_text=ocr_text, candidates=[])

    # ── Algoritma 3 — Levenshtein ile en iyi eşleşmeleri bul ──────────────
    matches = find_best_matches(ocr_text, med_names, top_n=5)
    candidates = [
        OCRMatchCandidate(
            medication_name=m["medication_name"],
            similarity=m["similarity"],
        )
        for m in matches
    ]

    logger.info(
        "Kullanıcı %d: OCR tarama — metin=%r, %d aday bulundu.",
        current_user.id,
        ocr_text,
        len(candidates),
    )

    return OCRScanResponse(ocr_raw_text=ocr_text, candidates=candidates)
