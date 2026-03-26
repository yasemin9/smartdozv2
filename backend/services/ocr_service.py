"""
SmartDoz - Modül 4: OCR Destekli Otomatik İlaç Tanıma Servisi

Pipeline:
    Görüntü Baytları
        → OpenCV Ön İşleme (RGB→Gray → Gaussian Blur → Otsu/Adaptive Threshold)
        → OCR Engine (Tesseract LSTM veya Google Cloud Vision)
        → Algoritma 3: Levenshtein Düzenleme Uzaklığı
        → PostgreSQL DB Eşleştirme (%85 eşik)
        → Aday Listesi → Kullanıcı Onayı (Flutter)
"""
import io
import logging
import os
import re
from abc import ABC, abstractmethod
from typing import Optional

import cv2
import numpy as np
import pytesseract

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────────────────────
# Algoritma 3 — Levenshtein Düzenleme Uzaklığı
# (Wagner–Fischer dinamik programlama, O(m·n) zaman, O(n) uzay)
#
# Neden gerekli?
#   İlaç kutuları parlak yüzeyli ve perspektif hatalarına açık olduğundan
#   OCR çıktısı gürültülüdür. Örn: "Par01" → "Parol", "8rufen" → "Brufen".
#   Basit string karşılaştırması bu hataları yakalayamaz; Levenshtein yakalar.
# ──────────────────────────────────────────────────────────────────────────────

def levenshtein_distance(s1: str, s2: str) -> int:
    """
    İki string arasındaki Levenshtein (düzenleme) uzaklığını döndürür.

    Üç temel işlem — her biri 1 maliyet:
        - Ekleme (insertion)
        - Silme  (deletion)
        - Değiştirme (substitution)

    Örnekler:
        levenshtein_distance("Par01",  "Parol")  → 2
        levenshtein_distance("8rufen", "Brufen") → 1
        levenshtein_distance("Aspirin", "Aspirin") → 0

    Args:
        s1: İlk string (OCR çıktısı tokeni).
        s2: İkinci string (DB ilaç adı).

    Returns:
        int: Minimum düzenleme uzaklığı. Küçükse daha yakın.
    """
    m, n = len(s1), len(s2)

    # Sadece önceki satırı tutarak O(n) bellekle çalış
    # dp[j] → s1[:i] ile s2[:j] arasındaki uzaklık
    dp = list(range(n + 1))          # Başlangıç: boş s1'den s2'ye geçiş

    for i in range(1, m + 1):
        prev_row = dp[:]              # Önceki satırın kopyası
        dp[0] = i                     # Boş s2'ye s1[:i]'den geçiş
        for j in range(1, n + 1):
            if s1[i - 1] == s2[j - 1]:
                dp[j] = prev_row[j - 1]       # Karakterler eşleşti → maliyet yok
            else:
                dp[j] = 1 + min(
                    prev_row[j],      # Silme:      s1'den bir karakter sil
                    dp[j - 1],        # Ekleme:     s2'ye bir karakter ekle
                    prev_row[j - 1],  # Değiştirme: bir karakteri değiştir
                )

    return dp[n]


def similarity_ratio(s1: str, s2: str) -> float:
    """
    Levenshtein tabanlı normalize edilmiş benzerlik oranı.

    Formül:
        similarity = 1 - (levenshtein_distance(s1, s2) / max(|s1|, |s2|))

    Örnekler:
        similarity_ratio("Par01",   "Parol")   → 0.60  (3/5 hata)
        similarity_ratio("Aspirin", "Aspirin") → 1.00  (tam eşleşme)
        similarity_ratio("ABC",     "XYZ")     → 0.00  (hiç benzemez)

    Returns:
        float: [0.0, 1.0] aralığında benzerlik skoru.
    """
    if not s1 and not s2:
        return 1.0
    max_len = max(len(s1), len(s2))
    if max_len == 0:
        return 1.0
    dist = levenshtein_distance(s1, s2)
    return 1.0 - dist / max_len


# ──────────────────────────────────────────────────────────────────────────────
# Görüntü Ön İşleme (OpenCV Pipeline)
# ──────────────────────────────────────────────────────────────────────────────

def preprocess_image(image_bytes: bytes) -> np.ndarray:
    """
    Ham görüntüyü OCR için hazırlar.

    Adımlar:
        1. RGB → Gri Tonlama (CV2.COLOR_BGR2GRAY)
        2. Gaussian Blur 5×5 — yüksek frekanslı gürültüyü bastır
        3. Otsu Thresholding — adaptif eşik değeri otomatik belirlenir
           Parlak kutu yüzeyleri için beyaz piksel oranı %20–%80 arasındaysa
           Otsu tercih edilir; aksi hâlde Adaptive Gaussian Thresholding kullanılır.

    Args:
        image_bytes: Ham görüntü baytları (JPEG / PNG / WebP).

    Returns:
        np.ndarray: İkili (binary) gri tonlamalı işlenmiş görüntü.

    Raises:
        ValueError: Görüntü decode edilemezse.
    """
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(
            "Görüntü decode edilemedi. Dosya bozuk veya desteklenmeyen format."
        )

    # Adım 1: RGB → Gri Tonlama
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Adım 2: Gaussian Blur — 5×5 çekirdek, sigma=0 (OpenCV otomatik hesaplar)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Adım 3a: Otsu Global Thresholding
    # (binarize_mode: "light bg, dark text" için THRESH_BINARY_INV dene)
    _, otsu = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Adım 3b: Adaptive Gaussian Thresholding — yedek, aydınlatma değişkenliği için
    adaptive = cv2.adaptiveThreshold(
        blurred,
        maxValue=255,
        adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        thresholdType=cv2.THRESH_BINARY,
        blockSize=11,
        C=2,
    )

    # Otsu'nun kalitesini değerlendir: beyaz piksel oranı %20–%80 ise güvenilir
    white_ratio = float(np.sum(otsu == 255)) / otsu.size
    chosen = otsu if 0.20 <= white_ratio <= 0.80 else adaptive

    logger.debug(
        "Görüntü ön işleme tamamlandı: boyut=%s, yöntem=%s, beyaz_oran=%.2f",
        img.shape[:2],
        "otsu" if 0.20 <= white_ratio <= 0.80 else "adaptive",
        white_ratio,
    )
    return chosen


# ──────────────────────────────────────────────────────────────────────────────
# OCR Motoru Arayüzü (Strategy Pattern)
# ──────────────────────────────────────────────────────────────────────────────

class OCREngine(ABC):
    """Tüm OCR motorları için soyut temel sınıf (Strategy Pattern)."""

    @abstractmethod
    def extract_text(self, image_data: bytes) -> str:
        """
        Görüntü baytlarından ham metin çıkarır.

        Args:
            image_data: Ham görüntü baytları.

        Returns:
            str: OCR'dan çıkan, temizlenmiş metin.
        """


# ──────────────────────────────────────────────────────────────────────────────
# Motor 1: Tesseract LSTM
# ──────────────────────────────────────────────────────────────────────────────

class TesseractOCREngine(OCREngine):
    """
    LSTM tabanlı Tesseract OCR motoru.

    Windows'ta önce ortam değişkeni TESSERACT_CMD kontrol edilir;
    bulunamazsa standart kurulum yolu denenir.
    Türkiye dil paketi kurulu değilse otomatik olarak sadece 'eng' kullanılır.
    """

    _DEFAULT_WIN_PATH = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

    def __init__(self, tesseract_cmd: Optional[str] = None) -> None:
        # Öncelik sırası: 1) constructor arg, 2) env var, 3) Windows default
        cmd = (
            tesseract_cmd
            or os.environ.get("TESSERACT_CMD")
            or (self._DEFAULT_WIN_PATH if os.path.isfile(self._DEFAULT_WIN_PATH) else None)
        )
        if cmd:
            pytesseract.pytesseract.tesseract_cmd = cmd
            logger.info("Tesseract path: %s", cmd)

    def _get_config(self) -> str:
        """Kurulu dil paketlerine göre Tesseract konfigürasyon string'i üretir."""
        try:
            available = pytesseract.get_languages(config="")
            if "tur" in available:
                langs = "tur+eng"
            else:
                langs = "eng"
                logger.warning(
                    "Türkçe dil paketi (tur) bulunamadı. Yalnızca 'eng' kullanılıyor. "
                    "Dil paketi indirmek için: "
                    "https://github.com/tesseract-ocr/tessdata"
                )
        except Exception:
            langs = "eng"
        # --oem 1  → LSTM Only
        # --psm 11 → Sparse text (dağınık metin, kutu yüzeyleri için ideal)
        return f"--oem 1 --psm 11 -l {langs}"

    def extract_text(self, image_data: bytes) -> str:
        processed = preprocess_image(image_data)
        custom_config = self._get_config()
        logger.info("Tesseract config: %s", custom_config)

        try:
            raw_text: str = pytesseract.image_to_string(processed, config=custom_config)
        except pytesseract.TesseractNotFoundError as exc:
            logger.error("Tesseract OCR bulunamadı: %s", exc)
            raise RuntimeError(
                "Tesseract OCR bulunamadı. "
                "Kurulum yolu: C:\\Program Files\\Tesseract-OCR\\tesseract.exe "
                "— PATH'e ekleyin veya TESSERACT_CMD ortam değişkenini ayarlayın."
            ) from exc
        except Exception as exc:
            logger.error("Tesseract OCR hata: %s", exc)
            raise RuntimeError(f"OCR işlemi başarısız: {exc}") from exc

        cleaned = _clean_ocr_output(raw_text)
        logger.info("Tesseract OCR → %r", cleaned)
        return cleaned


# ──────────────────────────────────────────────────────────────────────────────
# Motor 2: Google Cloud Vision API (Alternatif / Bulut Tabanlı)
# ──────────────────────────────────────────────────────────────────────────────

class GoogleVisionOCREngine(OCREngine):
    """
    Google Cloud Vision API tabanlı OCR motoru.

    Bu motor daha yüksek doğruluk sunar ancak internet bağlantısı
    ve servis hesabı kimlik bilgileri gerektirir.

    Kurulum:
        pip install google-cloud-vision

    Ortam değişkeni:
        GOOGLE_APPLICATION_CREDENTIALS = "/path/to/service-account.json"
    """

    def extract_text(self, image_data: bytes) -> str:
        try:
            from google.cloud import vision as gv  # type: ignore[import]
        except ImportError as exc:
            raise RuntimeError(
                "google-cloud-vision paketi yüklü değil. "
                "Kurulum: pip install google-cloud-vision"
            ) from exc

        client = gv.ImageAnnotatorClient()
        image = gv.Image(content=image_data)
        response = client.text_detection(image=image)

        if response.error.message:
            raise RuntimeError(
                f"Google Cloud Vision API hatası: {response.error.message}"
            )

        annotations = response.text_annotations
        if not annotations:
            return ""

        # İlk annotation tüm sayfanın birleşik metnini içerir
        raw_text: str = annotations[0].description
        cleaned = _clean_ocr_output(raw_text)
        logger.info("Google Vision OCR → %r", cleaned)
        return cleaned


# ──────────────────────────────────────────────────────────────────────────────
# OCR Çıktısı Temizleme
# ──────────────────────────────────────────────────────────────────────────────

def _clean_ocr_output(text: str) -> str:
    """
    OCR çıktısını ilaç ismi arama için normalleştirir.

    İşlemler:
        - Yalnızca harf, rakam ve boşlukları tut (Türkçe karakterler dahil)
        - Çoklu boşlukları tek boşluğa indir
        - Baştaki / sondaki boşlukları sil
    """
    cleaned = re.sub(r"[^a-zA-Z0-9çğışöüÇĞİŞÖÜ\s]", " ", text)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


# ──────────────────────────────────────────────────────────────────────────────
# İlaç Eşleştirme — Algoritma 3 uygulaması
# ──────────────────────────────────────────────────────────────────────────────

SIMILARITY_THRESHOLD = 0.85  # %85 eşiği: güvenilir eşleşme için minimum oran


def find_best_matches(
    ocr_text: str,
    medication_names: list[str],
    top_n: int = 5,
) -> list[dict]:
    """
    OCR metnindeki tokenleri, DB'deki ilaç isimleriyle Levenshtein ile karşılaştırır.

    Algoritma (Düzeltilmiş — Token-to-Token):
        1. OCR metnini büyük harfe çevir ve tokenlere böl.
        2. Her ilaç adını da tokenlerine böl.
        3. Her OCR tokeni ile her ilaç tokenini çapraz karşılaştır.
           → "ACNELYSE" ile "ACNELYSE %0.025 KREM"[0] = "ACNELYSE" → %100
        4. En iyi çift skorunu al.
        5. Eşik (%85) üzeri kalan adayları azalan sıraya göre sırala.

    Neden token-to-token gerekli?
        Eski yöntem: similarity_ratio("ACNELYSE", "ACNELYSE %0.025 KREM")
            → düzenleme uzaklığı = 12, max_len = 20 → skor = 0.40 → BAŞARISIZ
        Yeni yöntem: similarity_ratio("ACNELYSE", "ACNELYSE")  [ilaç adının ilk tokenı]
            → düzenleme uzaklığı = 0, max_len = 8 → skor = 1.00 → EŞLEŞME ✓

    Kısa token filtresi: 3 karakterden kısa tokenlar atlanır
        → "%0", "MG", "20G" gibi dozaj bilgileri yanlış eşleşmeye neden olmasın.

    Args:
        ocr_text:          OCR çıktısı (birden fazla kelime içerebilir).
        medication_names:  PostgreSQL global_medications tablosundaki ürün adları.
        top_n:             Döndürülecek maksimum aday sayısı.

    Returns:
        List[dict]: Her öğe {"medication_name": str, "similarity": float} içerir.
    """
    ocr_tokens = [t for t in ocr_text.upper().split() if len(t) >= 3]
    if not ocr_tokens:
        return []

    scored: list[dict] = []

    for med_name in medication_names:
        med_tokens = [t for t in med_name.upper().split() if len(t) >= 3]
        if not med_tokens:
            continue

        # Çapraz token karşılaştırması — her OCR tokeni × her ilaç tokenı
        best = 0.0
        for ocr_tok in ocr_tokens:
            for med_tok in med_tokens:
                s = similarity_ratio(ocr_tok, med_tok)
                if s > best:
                    best = s
                if best == 1.0:
                    break  # Tam eşleşme — daha fazla karşılaştırmaya gerek yok
            if best == 1.0:
                break

        if best >= SIMILARITY_THRESHOLD:
            scored.append(
                {
                    "medication_name": med_name,
                    "similarity": round(best, 4),
                }
            )

    # Azalan sıraya göre sırala ve ilk top_n kaydı döndür
    scored.sort(key=lambda x: x["similarity"], reverse=True)
    return scored[:top_n]

