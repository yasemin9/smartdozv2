import asyncio
from database import AsyncSessionLocal
from models import Medication
from sqlalchemy import inspect

async def inspect_medication():
    async with AsyncSessionLocal() as db:
        # Medication modeline ait tüm sütunları listele
        mapper = inspect(Medication)
        print("📋 Medication Modeli - Tüm Sütunlar:")
        print("=" * 60)
        for column in mapper.columns:
            print(f"  • {column.name} ({column.type})")
        print("=" * 60)
        
        # Veritabanından ilk ilaçları al
        from sqlalchemy import select
        query = select(Medication).limit(3)
        result = await db.execute(query)
        meds = result.scalars().all()
        
        print("\n📦 Veritabanındaki İlk 3 İlaç:")
        for med in meds:
            print(f"  • {med}")

if __name__ == "__main__":
    asyncio.run(inspect_medication())
    