-- 1. GlobalMedication tablosuna prospectus_link sütunu ekle
ALTER TABLE global_medications
ADD COLUMN IF NOT EXISTS prospectus_link TEXT;

CREATE INDEX IF NOT EXISTS idx_global_med_prospectus_link 
    ON global_medications(prospectus_link);

-- 2. Yeni Prospectus tablosu
CREATE TABLE IF NOT EXISTS prospectus (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(500) NOT NULL UNIQUE,
    prospectus_link TEXT NOT NULL,
    full_text TEXT,
    summary_text TEXT,
    is_summarized BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_prospectus_product_name ON prospectus(product_name);
CREATE INDEX IF NOT EXISTS idx_prospectus_is_summarized ON prospectus(is_summarized);

-- 3. ProspectusAnalytics tablosu
CREATE TABLE IF NOT EXISTS prospectus_analytics (
    id SERIAL PRIMARY KEY,
    prospectus_id INTEGER NOT NULL UNIQUE REFERENCES prospectus(id) ON DELETE CASCADE,
    view_count INTEGER DEFAULT 0 CHECK (view_count >= 0),
    unique_viewers INTEGER DEFAULT 0 CHECK (unique_viewers >= 0),
    last_viewed TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. ProspectusUserReading tablosu
CREATE TABLE IF NOT EXISTS prospectus_user_reading (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    prospectus_id INTEGER NOT NULL REFERENCES prospectus(id) ON DELETE CASCADE,
    view_type VARCHAR(20) DEFAULT 'summary' CHECK (view_type IN ('summary', 'full_text')),
    read_duration_seconds INTEGER CHECK (read_duration_seconds >= 0),
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, prospectus_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reading_user ON prospectus_user_reading(user_id);
CREATE INDEX IF NOT EXISTS idx_user_reading_prospectus ON prospectus_user_reading(prospectus_id);