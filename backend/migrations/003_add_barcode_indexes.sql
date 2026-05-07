-- SmartDoz - Modül 4: Barkod Okuma ve Eşleştirme İçin Veritabanı Güncellemeleri
-- Tarih: 2026-05-04

-- ──────────────────────────────────────────────────────────────────────────────
-- Migrasyon 003: Barkod Desteği Ekleme
-- ──────────────────────────────────────────────────────────────────────────────

-- 1. global_medications tablosunda barcode alanı için indeks (zaten var olabilir)
-- Eğer zaten varsa, bu komut hata vermez (IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_global_medications_barcode 
    ON global_medications(barcode) 
    WHERE barcode IS NOT NULL;

-- 2. medications tablosunda barcode alanı için indeks
CREATE INDEX IF NOT EXISTS idx_medications_barcode 
    ON medications(barcode) 
    WHERE barcode IS NOT NULL;

-- 3. Hızlı Arama için Barkod + Kullanıcı Kombinasyonu (medications'da)
-- Kullanıcının kendi ilaçları arasında barkod araması hızlı olacak
CREATE INDEX IF NOT EXISTS idx_medications_user_barcode 
    ON medications(user_id, barcode) 
    WHERE barcode IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────────
-- Not: Barcode alanı zaten models.py'de tanımlanmış, bu migration sadece
--      veritabanı İndexi yapılandırması içindir.
-- ──────────────────────────────────────────────────────────────────────────────

-- Örnek Sorgu: Barkod ile hızlı arama
-- SELECT * FROM global_medications WHERE barcode = '5901234123457';

-- Örnek: Kullanıcının belirli barkodlu ilaçları
-- SELECT * FROM medications WHERE user_id = 1 AND barcode = '5901234123457';
