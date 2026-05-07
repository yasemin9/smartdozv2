"""
SmartDoz - Modül 4: Barkod Okuma ve Eşleştirme Servisi

Pipeline:
    Görüntü Baytları
        → OpenCV Ön İşleme (RGB→Gray → Gaussian Blur)
        → Pyzbar Barkod Tanıma (EAN-13, UPC, Code128 vb.)
        → Barkod Değeri Elde Etme
        → PostgreSQL DB Eşleştirme (Kesin Eşleşme)
        → Sonuç: İlaç Verileri (varsa) → Kullanıcı Onayı (Flutter)

Barkod Formatları:
    - EAN-13: Avrupa / Türkiye standart ilaç barkodu (13 haneli)
    - EAN-8: Küçük ambalajlar için (8 haneli)
    - UPC-A: Amerika standart (12 haneli, başında 0)
    - Code128: Veri taşıyan barkod türü
"""

import io
import logging
from typing import Optional

import cv2
import numpy as np
from pyzbar import pyzbar

logger = logging.getLogger(__name__)


class BarcodeDecoder:
    """
    Barkod özütleme ve tanıma motoru.
    
    OpenCV ön işleme sonrası pyzbar ile barkod tiplerini tanır:
    EAN-13, EAN-8, UPC-A, Code128, vb.
    """
    
    # Desteklenen barkod formatları (ISO/IEC standartları)
    SUPPORTED_FORMATS = {
        "QRCODE",
        "EAN13",
        "EAN8",
        "UPCA",
        "UPCE",
        "CODE128",
        "CODE39",
        "ITF",
    }
    
    @staticmethod
    def _preprocess_image(image_bytes: bytes) -> np.ndarray:
        """
        OpenCV ile görüntü ön işlemesi (Geliştirilmiş).
        
        Adımlar:
            1. Baytları OpenCV formatına dönüştür
            2. Gri tonlamaya çevir (RGB→Gray)
            3. Morfolojik işlemler (gürültü azaltma)
            4. Adaptif Threshold (ışık değişkenliğine karşı robust)
            5. Ek temizleme (morfolojik açma/kapama)
        
        Geliştirilmiş Pipeline:
            - Dilation + Erosion: Barkod çizgilerini netleştir
            - Adaptif threshold yerine OTSU + Adaptif kombinasyon
            - Kontrastı artır (CLAHE - Contrast Limited Adaptive Histogram Equalization)
        
        Args:
            image_bytes: Görüntü baytları (JPEG/PNG/WebP)
            
        Returns:
            np.ndarray: İkili (0-255) ön işlenmiş görüntü
        """
        # Baytları NumPy dizisine dönüştür
        nparr = np.frombuffer(image_bytes, np.uint8)
        
        # OpenCV'ye dönüştür (BGR formatında)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise ValueError("Görüntü dekolanabilir değil. Desteklenen formatlar: JPEG, PNG, WebP")
        
        # Gri tonlamaya çevir
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Kontrastı artır — CLAHE (Contrast Limited Adaptive Histogram Equalization)
        # Barkodun çizgilerini netleştirmek için
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(gray)
        
        # Gürültü azaltma — Bilateral Filter (kenarları koruyan)
        # Gaussian Blur yerine Bilateral Filter kullan
        denoised = cv2.bilateralFilter(enhanced, 9, 75, 75)
        
        # Gürültü azaltma — Gaussian Blur (2. adım)
        blurred = cv2.GaussianBlur(denoised, (5, 5), 0)
        
        # Adaptif threshold — ışık değişkenliğine dayanıklı
        # blockSize: 11 (tekrar eden paternler için)
        # C: 2 (sabit çıkarılan değer)
        adaptive = cv2.adaptiveThreshold(
            blurred,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            blockSize=11,
            C=2,
        )
        
        # Morfolojik işlemler — barkod çizgilerini netleştir
        # Kernel oluştur (barkod çizgilerine uygun boyut)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        
        # Kapama (Closing) — küçük delikleri doldur
        closed = cv2.morphologyEx(adaptive, cv2.MORPH_CLOSE, kernel, iterations=1)
        
        # Açma (Opening) — küçük nesneleri çıkar
        processed = cv2.morphologyEx(closed, cv2.MORPH_OPEN, kernel, iterations=1)
        
        logger.debug(
            "Görüntü ön işleme tamamlandı (geliştirilmiş): boyut=%s",
            img.shape[:2],
        )
        
        return processed
    
    @staticmethod
    def decode_barcode(image_bytes: bytes) -> Optional[str]:
        """
        Görüntüden barkod değeri okur (Geliştirilmiş).
        
        Pyzbar formatları:
            - EAN13: Türkiye ilaç standardi
            - EAN8: Küçük ambalajlar
            - UPC-A: Amerikan standardi
            - Code128: Genel amaçlı
        
        Geliştirilmiş Pipeline:
            1. Standart ön işlemeden barkod oku
            2. Başarısız olursa, görüntü rotasyonları dene (90°, 180°, 270°)
            3. Artan benzerliğe göre ilk bulunmuş barkodu döndür
        
        Args:
            image_bytes: Görüntü baytları
            
        Returns:
            str: Barkod değeri (örn: "5901234123457")
                 Bulunamadıysa None döndürür
            
        Raises:
            ValueError: Görüntü dekolanabilir değilse
        """
        try:
            # Ana görüntüyü decode et
            nparr = np.frombuffer(image_bytes, np.uint8)
            original_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if original_img is None:
                raise ValueError("Görüntü dekolanabilir değil")
            
            # Ön işleme + barkod taraması
            processed = BarcodeDecoder._preprocess_image(image_bytes)
            barcodes = pyzbar.decode(processed)
            
            if barcodes:
                barcode = barcodes[0]
                barcode_value = barcode.data.decode("utf-8")
                barcode_format = barcode.type
                logger.info(
                    f"Barkod okodu başarılı (1. deneme): {barcode_format} — {barcode_value}"
                )
                return barcode_value
            
            # Başarısız olursa, görüntü rotasyonlarını dene
            logger.info("Barkod bulunamadı. Rotasyonlu taraması başlıyor...")
            
            for rotation_angle in [90, 180, 270]:
                # Görüntüyü döndür
                h, w = original_img.shape[:2]
                center = (w // 2, h // 2)
                rotation_matrix = cv2.getRotationMatrix2D(center, rotation_angle, 1.0)
                rotated = cv2.warpAffine(original_img, rotation_matrix, (w, h))
                
                # Döndürülmüş görüntüyü ön işle
                # cv2.cvtColor ile gri tonlamaya çevir
                gray_rotated = cv2.cvtColor(rotated, cv2.COLOR_BGR2GRAY)
                
                # CLAHE uygula
                clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
                enhanced_rotated = clahe.apply(gray_rotated)
                
                # Bilateral Filter
                denoised_rotated = cv2.bilateralFilter(enhanced_rotated, 9, 75, 75)
                
                # Gaussian Blur
                blurred_rotated = cv2.GaussianBlur(denoised_rotated, (5, 5), 0)
                
                # Adaptif Threshold
                adaptive_rotated = cv2.adaptiveThreshold(
                    blurred_rotated,
                    255,
                    cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                    cv2.THRESH_BINARY,
                    blockSize=11,
                    C=2,
                )
                
                # Morfolojik işlemler
                kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
                closed_rotated = cv2.morphologyEx(adaptive_rotated, cv2.MORPH_CLOSE, kernel, iterations=1)
                processed_rotated = cv2.morphologyEx(closed_rotated, cv2.MORPH_OPEN, kernel, iterations=1)
                
                # Barkod taraması
                barcodes = pyzbar.decode(processed_rotated)
                
                if barcodes:
                    barcode = barcodes[0]
                    barcode_value = barcode.data.decode("utf-8")
                    barcode_format = barcode.type
                    logger.info(
                        f"Barkod okodu başarılı ({rotation_angle}° döndürme): {barcode_format} — {barcode_value}"
                    )
                    return barcode_value
            
            logger.info("Tüm rotasyonlarda barkod bulunamadı")
            return None
            
        except Exception as e:
            logger.error(f"Barkod okuma hatası: {e}")
            raise ValueError(f"Barkod okuma başarısız: {str(e)}")
    
    @staticmethod
    def extract_all_barcodes(image_bytes: bytes) -> list[str]:
        """
        Görüntüdeki tüm barkodları çıkarır (Geliştirilmiş).
        
        Bazı kutuların 1'den fazla barkodu olabilir
        (EAN-13 ve ürün kodu gibi). Bu metod hepsini döndürür.
        
        Geliştirilmiş Pipeline:
            1. Orijinal görüntüde tüm barkodları bul
            2. Bulunamazsa, rotasyonlu taramalar yap
            3. Tüm barkodları benzersiz kıl ve döndür
        
        Args:
            image_bytes: Görüntü baytları
            
        Returns:
            list[str]: Bulunan barkod değerleri (başarı sırası ile, tekrarsız)
            
        Raises:
            ValueError: Görüntü dekolanabilir değilse
        """
        try:
            # Ana görüntüyü decode et
            nparr = np.frombuffer(image_bytes, np.uint8)
            original_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if original_img is None:
                raise ValueError("Görüntü dekolanabilir değil")
            
            found_barcodes = set()  # Tekrar eden barkodları önlemek için set
            
            # Adım 1: Ana görüntüde tara
            processed_img = BarcodeDecoder._preprocess_image(image_bytes)
            barcodes = pyzbar.decode(processed_img)
            
            for barcode in barcodes:
                value = barcode.data.decode("utf-8")
                found_barcodes.add(value)
                logger.debug(f"Bulunan barkod (orijinal): {barcode.type} — {value}")
            
            # Adım 2: Başarısız olursa rotasyonlu taramalar yap
            if not found_barcodes:
                logger.info("Ana görüntüde barkod bulunamadı. Rotasyonlu taraması başlıyor...")
                
                h, w = original_img.shape[:2]
                center = (w // 2, h // 2)
                
                for rotation_angle in [90, 180, 270]:
                    rotation_matrix = cv2.getRotationMatrix2D(center, rotation_angle, 1.0)
                    rotated = cv2.warpAffine(original_img, rotation_matrix, (w, h))
                    
                    # Döndürülmüş görüntüyü ön işle
                    gray_rotated = cv2.cvtColor(rotated, cv2.COLOR_BGR2GRAY)
                    
                    # CLAHE uygula
                    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
                    enhanced_rotated = clahe.apply(gray_rotated)
                    
                    # Bilateral Filter
                    denoised_rotated = cv2.bilateralFilter(enhanced_rotated, 9, 75, 75)
                    
                    # Gaussian Blur
                    blurred_rotated = cv2.GaussianBlur(denoised_rotated, (5, 5), 0)
                    
                    # Adaptif Threshold
                    adaptive_rotated = cv2.adaptiveThreshold(
                        blurred_rotated,
                        255,
                        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                        cv2.THRESH_BINARY,
                        blockSize=11,
                        C=2,
                    )
                    
                    # Morfolojik işlemler
                    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
                    closed_rotated = cv2.morphologyEx(adaptive_rotated, cv2.MORPH_CLOSE, kernel, iterations=1)
                    processed_rotated = cv2.morphologyEx(closed_rotated, cv2.MORPH_OPEN, kernel, iterations=1)
                    
                    # Barkod taraması
                    barcodes = pyzbar.decode(processed_rotated)
                    
                    for barcode in barcodes:
                        value = barcode.data.decode("utf-8")
                        found_barcodes.add(value)
                        logger.debug(f"Bulunan barkod ({rotation_angle}° döndürme): {barcode.type} — {value}")
                    
                    if found_barcodes:
                        break
            
            return list(found_barcodes)
            
        except Exception as e:
            logger.error(f"Çoklu barkod özütleme hatası: {e}")
            raise ValueError(f"Barkod özütleme başarısız: {str(e)}")


class BarcodeMatchResult:
    """Barkod eşleştirme sonucunu tutacak model (SQLAlchemy yerine basit sınıf)."""
    
    def __init__(
        self,
        found: bool,
        barcode: str,
        medication_id: Optional[int] = None,
        medication_name: Optional[str] = None,
        confidence: float = 1.0,
        message: str = "",
    ):
        self.found = found
        self.barcode = barcode
        self.medication_id = medication_id
        self.medication_name = medication_name
        self.confidence = confidence  # Kesin eşleşme için 1.0
        self.message = message
    
    def to_dict(self) -> dict:
        """Pydantic şemasına dönüştürmek için dict döndür."""
        return {
            "found": self.found,
            "barcode": self.barcode,
            "medication_id": self.medication_id,
            "medication_name": self.medication_name,
            "confidence": self.confidence,
            "message": self.message,
        }
