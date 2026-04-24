-- 1. Görünüm tipi için ENUM oluştur
DO $$ BEGIN
    CREATE TYPE view_type_enum AS ENUM ('summary', 'full_text');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Prospektüs Ana Tablosu
CREATE TABLE IF NOT EXISTS prospectus (
    id SERIAL PRIMARY KEY,
    medication_id INTEGER REFERENCES global_medications(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL UNIQUE,
    prospectus_link TEXT NOT NULL,
    full_text TEXT,
    summary_text TEXT,
    is_summarized BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Arama optimizasyonu (PostgreSQL Full Text Search)
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('turkish', 
            COALESCE(product_name, '') || ' ' || 
            COALESCE(summary_text, ''))
    ) STORED
);

-- 3. Analitik Tablosu
CREATE TABLE IF NOT EXISTS prospectus_analytics (
    id SERIAL PRIMARY KEY,
    prospectus_id INTEGER NOT NULL UNIQUE REFERENCES prospectus(id) ON DELETE CASCADE,
    view_count INTEGER DEFAULT 0,
    unique_viewers INTEGER DEFAULT 0,
    last_viewed TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Kullanıcı Okuma Geçmişi
CREATE TABLE IF NOT EXISTS prospectus_user_reading (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    prospectus_id INTEGER NOT NULL REFERENCES prospectus(id) ON DELETE CASCADE,
    view_type view_type_enum DEFAULT 'summary',
    read_duration_seconds INTEGER,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE (user_id, prospectus_id),
    CONSTRAINT valid_duration CHECK (read_duration_seconds >= 0)
);

-- 5. Tüm İndeksler
CREATE INDEX IF NOT EXISTS idx_prospectus_med_id 
    ON prospectus(medication_id);

CREATE INDEX IF NOT EXISTS idx_prospectus_is_summarized 
    ON prospectus(is_summarized);

CREATE INDEX IF NOT EXISTS idx_prospectus_search 
    ON prospectus USING gin(search_vector);

CREATE INDEX IF NOT EXISTS idx_user_reading_user 
    ON prospectus_user_reading(user_id);

CREATE INDEX IF NOT EXISTS idx_user_reading_prospectus 
    ON prospectus_user_reading(prospectus_id);

CREATE INDEX IF NOT EXISTS idx_analytics_last_viewed 
    ON prospectus_analytics(last_viewed);

CREATE INDEX IF NOT EXISTS idx_product_name 
    ON prospectus(product_name);

-- 6. Trigger - Otomatik timestamp güncelleme
CREATE OR REPLACE FUNCTION update_prospectus_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prospectus_update_trigger ON prospectus;
CREATE TRIGGER prospectus_update_trigger
BEFORE UPDATE ON prospectus
FOR EACH ROW
EXECUTE FUNCTION update_prospectus_timestamp();

-- 7. Analytics trigger
CREATE OR REPLACE FUNCTION update_analytics_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS analytics_update_trigger ON prospectus_analytics;
CREATE TRIGGER analytics_update_trigger
BEFORE UPDATE ON prospectus_analytics
FOR EACH ROW
EXECUTE FUNCTION update_analytics_timestamp();