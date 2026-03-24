"""
Mevcut duplicate DoseLog kayıtlarını temizler ve
UniqueConstraint'i veritabanına ekler.

Çalıştırma:
    cd backend
    .venv\Scripts\python.exe fix_duplicate_logs.py
"""
import asyncio
from sqlalchemy import text
from database import engine


CLEAN_DUPLICATES_SQL = """
-- Her (medication_id, scheduled_time) grubu için en küçük id'yi tut,
-- diğerlerini sil.
DELETE FROM dose_logs
WHERE id NOT IN (
    SELECT MIN(id)
    FROM dose_logs
    GROUP BY medication_id, scheduled_time
);
"""

ADD_CONSTRAINT_SQL = """
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_dose_log_med_time'
    ) THEN
        ALTER TABLE dose_logs
        ADD CONSTRAINT uq_dose_log_med_time
        UNIQUE (medication_id, scheduled_time);
    END IF;
END
$$;
"""


async def main():
    async with engine.begin() as conn:
        print("Duplicate loglar temizleniyor...")
        result = await conn.execute(text(CLEAN_DUPLICATES_SQL))
        print(f"  Silinen satır sayısı: {result.rowcount}")

        print("UniqueConstraint ekleniyor...")
        await conn.execute(text(ADD_CONSTRAINT_SQL))
        print("  Constraint eklendi (veya zaten vardı).")

    print("Tamamlandı.")


if __name__ == "__main__":
    asyncio.run(main())
