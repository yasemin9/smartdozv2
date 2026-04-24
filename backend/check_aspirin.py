import asyncio
from database import AsyncSessionLocal
from models import Medication
from sqlalchemy import select

async def check_aspirin():
    async with AsyncSessionLocal() as db:
        # Aspirin'i ara (product_name yerine name kullan)
        query = select(Medication).where(
            Medication.name.like('%ASPIRIN%100%')
        )
        result = await db.execute(query)
        aspirin = result.scalars().first()
        
        if aspirin:
            print(f"✅ Bulundu: {aspirin.name}")
            print(f"📊 ID: {aspirin.id}")
            print(f"📝 Etkin Madde: {aspirin.active_ingredient or 'Yok'}")
            print(f"💊 Doz Formu: {aspirin.dosage_form}")
            print(f"📅 Son Kullanma: {aspirin.expiry_date}")
            # Description alanı var mı diye kontrol et
            if hasattr(aspirin, 'description'):
                desc = aspirin.description[:100] if aspirin.description else 'BOŞ'
                print(f"📄 Açıklama: {desc}")
            else:
                print(f"⚠️ Description alanı modelde yok!")
        else:
            print("❌ ASPIRIN 100 MG BULUNAMADI")
            
            # Tüm ilaçları listele
            query_all = select(Medication).limit(5)
            result_all = await db.execute(query_all)
            all_meds = result_all.scalars().all()
            
            print("\n📋 Veritabanındaki İlk 5 İlaç:")
            for med in all_meds:
                print(f"  • {med.name}")

# Çalıştır
if __name__ == "__main__":
    asyncio.run(check_aspirin())