"""pg_trgm uzantisini etkinlestirir ve DrugInteractions tablosuna GIN index ekler."""
import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy import text
from database import engine


async def main():
    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS pg_trgm"))
        print("pg_trgm uzantisi etkinlestirildi.")

        await conn.execute(text(
            "CREATE INDEX IF NOT EXISTS idx_di_drug1_trgm "
            'ON "DrugInteractions" USING GIN (LOWER(drug1) gin_trgm_ops)'
        ))
        await conn.execute(text(
            "CREATE INDEX IF NOT EXISTS idx_di_drug2_trgm "
            'ON "DrugInteractions" USING GIN (LOWER(drug2) gin_trgm_ops)'
        ))
        print("GIN indexler olusturuldu.")

    print("Tamamlandi.")


if __name__ == "__main__":
    asyncio.run(main())
