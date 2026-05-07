"""
SmartDoz - Modül 4: OCR İlaç Tanıma Router'ı (DEVRE DIŞI)

⚠️ DEPRECATION WARNING: OCR-based drug name reading DISABLED
Yalnızca barkod üzerinden ilaç eşleştirmesi yapılır.

POST /ocr/scan
    ❌ DEPRECATED: İçbarkod ve yazı tanıma ile ilaç adı okuma artık desteklenmiyor.
    ✅ Bunun yerine POST /barcode/scan endpoint'ini kullanın.

Tüm endpoint'ler JWT ile korumalıdır.
"""
import logging

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from database import get_db
from models import User
from schemas import OCRScanResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ocr", tags=["Modül 4 — OCR İlaç Tanıma (DEPRECATED)"])

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


@router.post(
    "/scan",
    response_model=OCRScanResponse,
    summary="❌ DEPRECATED: OCR-based drug name reading disabled",
    deprecated=True,
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
    ⚠️ **DEPRECATED ENDPOINT** — Bu endpoint artık desteklenmiyor.

    **Değişiklik Nedeni:**
    Sistem mimarisinde iyileştirme için ilaç eşleştirmesi artık **yalnızca barkod** üzerinden yapılmaktadır.
    OCR-based drug name reading (ilaç adı okuma) işlevi devre dışı bırakılmıştır.

    **Nedenler:**
    - 📊 Barkod: %99.9 doğruluk, kesin eşleşme
    - 📝 OCR: Gürültüye duyarlı, fuzzy matching, kullanıcı doğrulaması gerekli
    - ⚡ Performans: Barkod çok daha hızlı
    - 🎯 Kullanıcı Deneyimi: Bir adım daha az (OCR onayı gerekmez)

    **Alternatif Endpoint:**
    👉 **Bunun yerine `POST /barcode/scan` kullanın**

    **Yeni Pipeline:**
    1. `POST /barcode/scan` → Görüntü yükle
    2. Sistem otomatik olarak barkodu okur
    3. Barkod değeri ile veritabanında kesin eşleşme arar
    4. Sonucu döndürür

    **Örnek istek:**
    ```python
    POST /barcode/scan
    Content-Type: multipart/form-data

    file: <image.jpg>
    ```

    **Başarı Yanıtı:**
    ```json
    {
      "found": true,
      "barcode": "5901234123457",
      "medication_id": 42,
      "medication_name": "İlaç Adı",
      "confidence": 1.0,
      "message": "✅ İlaç başarıyla eşleştirildi"
    }
    ```

    **Hata Yanıtı:**
    ```json
    {
      "found": false,
      "barcode": "",
      "medication_id": null,
      "medication_name": null,
      "confidence": 0.0,
      "message": "Barkod bulunamadı. Lütfen daha net bir fotoğraf çekip tekrar deneyin."
    }
    ```

    ---

    ℹ️ **OCR İşlemini Nasıl Yapabilirim?**
    
    Eğer OCR tabanlı metin çıkarma işlemini doğrudan yapmak istiyorsanız (ilaç eşleştirmesi olmadan),
    bu işlemi client-side (Flutter) veya custom endpoint aracılığıyla gerçekleştirebilirsiniz.
    Ancak **ilaç eşleştirmesi her zaman barkod üzerinden olmalıdır**.
    """
    # Dosya türü doğrulaması (kullanıcının doğru istek gönderip göndermediğini kontrol et)
    content_type = (file.content_type or "").lower()
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=(
                f"Desteklenmeyen dosya türü: {content_type!r}. "
                "Yalnızca JPEG, PNG veya WebP kabul edilir."
            ),
        )

    # Boyut doğrulaması
    image_bytes = await file.read()
    if len(image_bytes) > _MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Görüntü boyutu 10 MB sınırını aşıyor.",
        )

    # ❌ ENDPOINT DEVRE DIŞI - Hata döndür
    logger.warning(
        f"Kullanıcı {current_user.id}: /ocr/scan endpoint deprecated — "
        f"Bunun yerine /barcode/scan kullanmalısınız."
    )
    
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail={
            "error": "DEPRECATED_ENDPOINT",
            "message": "OCR-based drug name reading has been discontinued.",
            "reason": "Drug matching is now exclusively through barcode reading for higher accuracy and performance.",
            "alternative": "Use POST /barcode/scan instead",
            "documentation": "https://smartdoz.example.com/docs#/barcode/scan_medication_barcode",
        },
    )

