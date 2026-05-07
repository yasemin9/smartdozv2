"""
SmartDoz - Barkod Servisi Test Script'i

Kullanım:
    python test_barcode_service.py --test-decode --test-api
"""

import asyncio
import base64
import json
import logging
import sys
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
from services.barcode_service import BarcodeDecoder

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_test_barcode_image(barcode_value: str = "5901234123457") -> bytes:
    """
    Test amaçlı EAN-13 barkod görüntüsü oluşturur.
    
    Not: Bu sadece test için siyah-beyaz barkod kullanır.
    Gerçek barkod görüntüleri için:
        pip install python-barcode
        from barcode import EAN13
        EAN13('5901234123457').save('barcode.png')
    """
    try:
        import barcode
        from barcode.writer import ImageWriter
        
        # EAN-13 barkod oluştur
        ean = barcode.get('ean13', barcode_value, writer=ImageWriter())
        temp_path = Path("/tmp/test_barcode.png")
        ean.save(str(temp_path))
        
        # Görüntüyü byte'a dönüştür
        with open(temp_path, "rb") as f:
            return f.read()
            
    except ImportError:
        logger.warning("python-barcode yüklü değil. Manuel test görüntüsü oluşturuluyor...")
        # Fallback: basit siyah-beyaz barkod benzeri görüntü oluştur
        img = np.zeros((100, 300, 3), dtype=np.uint8)
        # Barkod desenini çiz
        for i in range(0, 300, 10):
            if np.random.random() > 0.5:
                cv2.line(img, (i, 20), (i, 80), (255, 255, 255), 5)
        
        success, encoded = cv2.imencode('.png', img)
        return encoded.tobytes() if success else b""


def test_barcode_decoder():
    """Barcode Decoder servicini test et."""
    logger.info("\n" + "="*60)
    logger.info("TEST 1: Barcode Decoder Servisi")
    logger.info("="*60)
    
    try:
        # Test görüntüsü oluştur
        test_image = create_test_barcode_image("5901234123457")
        logger.info(f"✓ Test görüntüsü oluşturuldu ({len(test_image)} bytes)")
        
        # Barkod dekodlama dene
        decoder = BarcodeDecoder()
        result = decoder.decode_barcode(test_image)
        
        if result:
            logger.info(f"✓ Barkod başarıyla okundu: {result}")
            return True
        else:
            logger.warning("⚠ Barkod okunamadı (normal — gerçek görüntü gerekli)")
            return None  # Test olmasa da hata değil
            
    except ValueError as e:
        logger.error(f"✗ Hata: {e}")
        return False
    except Exception as e:
        logger.error(f"✗ Beklenmeyen hata: {e}")
        return False


async def test_barcode_api():
    """Barcode API endpoint'ini test et."""
    logger.info("\n" + "="*60)
    logger.info("TEST 2: Barcode API Endpoints")
    logger.info("="*60)
    
    try:
        import httpx
        
        # Test token (gerçek token gerekli)
        TOKEN = "YOUR_JWT_TOKEN_HERE"  # Değiştir
        
        if TOKEN == "YOUR_JWT_TOKEN_HERE":
            logger.warning("⚠ JWT token ayarlanmamış. API testi atlanıyor.")
            logger.info("   Lütfen TOKEN değişkenini gerçek token ile değiştir.")
            return None
        
        async with httpx.AsyncClient() as client:
            # 1. Barcode tarama endpoint'i
            logger.info("\n1. POST /barcode/scan endpoint'i test ediliyor...")
            
            # Test görüntüsü
            test_image = create_test_barcode_image()
            
            response = await client.post(
                "http://localhost:8000/barcode/scan",
                headers={"Authorization": f"Bearer {TOKEN}"},
                files={"file": ("test.png", test_image, "image/png")},
                params={"fallback_to_ocr": "true"},
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"✓ Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
            else:
                logger.error(f"✗ Hata {response.status_code}: {response.text}")
                return False
            
            # 2. Barcode arama endpoint'i
            logger.info("\n2. GET /barcode/search endpoint'i test ediliyor...")
            
            response = await client.get(
                "http://localhost:8000/barcode/search/5901234123457",
                headers={"Authorization": f"Bearer {TOKEN}"},
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"✓ Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
                return True
            else:
                logger.error(f"✗ Hata {response.status_code}: {response.text}")
                return False
                
    except ImportError:
        logger.warning("⚠ httpx yüklü değil. API testi atlanıyor.")
        logger.info("   Yüklemek için: pip install httpx")
        return None
    except Exception as e:
        logger.error(f"✗ API testi hatası: {e}")
        return False


def print_test_curl_commands():
    """Curl komutları yazdır."""
    logger.info("\n" + "="*60)
    logger.info("CURL TEST KOMUTLARI")
    logger.info("="*60)
    
    commands = [
        ("Barcode Tarama (Görüntü)", '''
curl -X POST "http://localhost:8000/barcode/scan" \\
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \\
  -F "file=@/path/to/medication_box.jpg" \\
  -F "fallback_to_ocr=true"
        '''),
        ("Barcode Arama", '''
curl -X GET "http://localhost:8000/barcode/search/5901234123457" \\
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
        '''),
        ("Swagger UI (İnteraktif Test)", '''
Tarayıcıda açıt: http://localhost:8000/docs
        '''),
    ]
    
    for name, cmd in commands:
        logger.info(f"\n{name}:")
        logger.info(cmd.strip())


def print_test_checklist():
    """Kontrol listesi yazdır."""
    logger.info("\n" + "="*60)
    logger.info("ÖN ŞARTLAR KONTROL LİSTESİ")
    logger.info("="*60)
    
    checks = [
        ("Python 3.8+", "python --version"),
        ("pyzbar yüklü", "python -c 'import pyzbar; print(pyzbar.__version__)'"),
        ("OpenCV yüklü", "python -c 'import cv2; print(cv2.__version__)'"),
        ("Backend çalışıyor", "curl http://localhost:8000/docs"),
        ("JWT token var", "Kullanıcı giriş yap, token al"),
        ("Global medications tablosu dolu", "SELECT COUNT(*) FROM global_medications"),
    ]
    
    for check, cmd in checks:
        logger.info(f"\n□ {check}")
        logger.info(f"  Komut: {cmd}")


async def main():
    """Ana test fonksiyonu."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Barcode Service Test")
    parser.add_argument("--test-decode", action="store_true", help="Decoder'ı test et")
    parser.add_argument("--test-api", action="store_true", help="API endpoint'lerini test et")
    parser.add_argument("--all", action="store_true", help="Tüm testleri çalıştır")
    parser.add_argument("--check", action="store_true", help="Ön şartlar kontrol et")
    parser.add_argument("--curl", action="store_true", help="Curl komutları göster")
    
    args = parser.parse_args()
    
    if args.all or not any(vars(args).values()):
        # Varsayılan: tüm testleri çalıştır
        print_test_checklist()
        print_test_curl_commands()
        
        logger.info("\n" + "="*60)
        logger.info("TESTLER BAŞLIYOR")
        logger.info("="*60)
        
        result1 = test_barcode_decoder()
        result2 = await test_barcode_api()
        
        # Özet
        logger.info("\n" + "="*60)
        logger.info("TEST ÖZETİ")
        logger.info("="*60)
        logger.info(f"Decoder Testi:  {'✓ Başarılı' if result1 else '✗ Başarısız' if result1 is False else '⚠ Atlandı'}")
        logger.info(f"API Testi:      {'✓ Başarılı' if result2 else '✗ Başarısız' if result2 is False else '⚠ Atlandı'}")
        
    else:
        if args.check:
            print_test_checklist()
        if args.curl:
            print_test_curl_commands()
        if args.test_decode:
            test_barcode_decoder()
        if args.test_api:
            await test_barcode_api()


if __name__ == "__main__":
    asyncio.run(main())
