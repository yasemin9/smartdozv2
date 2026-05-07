-- SmartDoz - Migration 004: Bakıcı (Caregiver) ve Bildirim Sistemi
-- Amaç: İlaç alınmadığında ilişkili caregivers'a otomatik bildirim göndermek

-- 1. Caregiver İlişkisi Tablosu
-- user_id: İlaç kullanan kişi
-- caregiver_user_id: Uyarı almak isteyen kişi (aile üyesi, doktor, bakıcı)
CREATE TABLE IF NOT EXISTS caregiver_relationships (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caregiver_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship_type VARCHAR(50) NOT NULL DEFAULT 'caregiver', -- 'parent', 'child', 'spouse', 'doctor', 'caregiver'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Aynı ilişki iki kez eklenemez
    UNIQUE (user_id, caregiver_user_id),
    -- Kendini caregiver yapamaz
    CONSTRAINT no_self_caregiver CHECK (user_id != caregiver_user_id)
);

-- 2. Bildirim Tablosu
-- Tip: MISSED_DOSE (ilaç atlandı), OVERDOSE (fazla doz), EXPIRY (ilaç son kat.), vb
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caregiver_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    dose_log_id INTEGER REFERENCES dose_logs(id) ON DELETE SET NULL,
    medication_id INTEGER REFERENCES medications(id) ON DELETE SET NULL,
    
    notification_type VARCHAR(50) NOT NULL, -- MISSED_DOSE, OVERDOSE, EXPIRY, etc
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. İndeksler - Hızlı sorgu için
CREATE INDEX IF NOT EXISTS idx_caregiver_relationships_user 
    ON caregiver_relationships(user_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_relationships_caregiver 
    ON caregiver_relationships(caregiver_user_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_relationships_active 
    ON caregiver_relationships(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_notifications_caregiver 
    ON notifications(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user 
    ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread 
    ON notifications(caregiver_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created 
    ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_dose_log 
    ON notifications(dose_log_id);

-- 4. Trigger - Caregiver İlişkisinin updated_at'i otomatik güncelle
CREATE OR REPLACE FUNCTION update_caregiver_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS caregiver_relationships_update_trigger ON caregiver_relationships;
CREATE TRIGGER caregiver_relationships_update_trigger
BEFORE UPDATE ON caregiver_relationships
FOR EACH ROW
EXECUTE FUNCTION update_caregiver_timestamp();

-- 5. Trigger - Notification'ın updated_at'i otomatik güncelle
CREATE OR REPLACE FUNCTION update_notification_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS notification_update_trigger ON notifications;
CREATE TRIGGER notification_update_trigger
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION update_notification_timestamp();

-- 6. Trigger - Bildirim okunduğunda read_at'i set et
CREATE OR REPLACE FUNCTION set_notification_read_time()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_read = TRUE AND OLD.is_read = FALSE THEN
        NEW.read_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS notification_read_trigger ON notifications;
CREATE TRIGGER notification_read_trigger
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION set_notification_read_time();
