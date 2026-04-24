-- Geçici bir yükleme tablosu oluşturalım
CREATE TABLE temp_csv_data (
    product_name TEXT,
    prospectus_link TEXT
);

-- CSV dosyasını bu tabloya bas (Dosya yolunu kendine göre güncelle)
COPY temp_csv_data(product_name, prospectus_link)
FROM 'C:/Users/Lenovo/Desktop/smartdozv2/data/ilac_prospektus_linkleri.csv'
DELIMITER ',' 
CSV HEADER;

--!! sonra bu yapılacak 

UPDATE global_medications g
SET prospectus_link = t.prospectus_link
FROM temp_csv_data t
WHERE UPPER(TRIM(g.product_name)) = UPPER(TRIM(t.product_name));

------------
-- Tablolara geçici temizleme sütunları ekle
ALTER TABLE global_medications ADD COLUMN IF NOT EXISTS clean_name TEXT;
ALTER TABLE temp_csv_data ADD COLUMN IF NOT EXISTS clean_name TEXT;

-- Boşlukları ve gürültüleri temizleyip bu sütunlara yaz (Saniyeler sürer)
UPDATE global_medications 
SET clean_name = REPLACE(REPLACE(REPLACE(REPLACE(UPPER(product_name), ' ', ''), '%', ''), '.', ''), '/', '');

UPDATE temp_csv_data 
SET clean_name = REPLACE(REPLACE(REPLACE(REPLACE(UPPER(product_name), ' ', ''), '%', ''), '.', ''), '/', '');





--!!

CREATE INDEX IF NOT EXISTS idx_clean_global ON global_medications(clean_name);
CREATE INDEX IF NOT EXISTS idx_clean_temp ON temp_csv_data(clean_name);

UPDATE global_medications SET clean_name = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(product_name), 'İ', 'I'), 'Ş', 'S'), 'Ğ', 'G'), 'Ü', 'U'), 'Ö', 'O'), 'Ç', 'C'), ' ', '');

UPDATE temp_csv_data SET clean_name = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(product_name), 'İ', 'I'), 'Ş', 'S'), 'Ğ', 'G'), 'Ü', 'U'), 'Ö', 'O'), 'Ç', 'C'), ' ', '');

------------------------


UPDATE global_medications g
SET prospectus_link = t.prospectus_link
FROM temp_csv_data t
WHERE g.prospectus_link IS NULL
  AND 
  -- Veritabanındaki ismi temizle
  REGEXP_REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(g.product_name), 'İ', 'I'), 'Ş', 'S'), 'Ğ', 'G'), 'Ü', 'U'), 'Ö', 'O'), 'Ç', 'C'),
    '[^A-Z0-9]', '', 'g'
  )
  = 
  -- CSV'deki ismi temizle
  REGEXP_REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(t.product_name), 'İ', 'I'), 'Ş', 'S'), 'Ğ', 'G'), 'Ü', 'U'), 'Ö', 'O'), 'Ç', 'C'),
    '[^A-Z0-9]', '', 'g'
  );




  --!!!!
UPDATE global_medications g
SET prospectus_link = t.prospectus_link
FROM temp_csv_data t
WHERE g.prospectus_link IS NULL
  AND (
    -- 1. KURAL: Marka eşleşmesi (Boşluksuz ve Türkçe karaktersiz)
    REPLACE(REPLACE(REPLACE(UPPER(t.product_name), 'İ', 'I'), ' ', ''), 'TABLET', '') 
    LIKE 
    '%' || REPLACE(REPLACE(REPLACE(UPPER(split_part(g.product_name, ' ', 1)), 'İ', 'I'), ' ', ''), 'TABLET', '') || '%'
    AND
    -- 2. KURAL: Doz kontrolü (Sadece ilaç isminde rakam varsa kontrol et)
    (
      CASE 
        WHEN g.product_name ~ '\d+' THEN 
          (t.product_name ~ SUBSTRING(g.product_name FROM '\d+'))
        ELSE TRUE -- Eğer doz bilgisi yoksa (örn: sadece krem), geçmesine izin ver
      END
    )
  );