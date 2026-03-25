"""
SmartDoz - Global İlaç Veritabanı Seed Scripti

PHPMyAdmin JSON export formatındaki ilac.json dosyasını
global_medications tablosuna yükler.

Kullanım (backend klasöründen):
    python seed_global_medications.py

ya da özel yol belirtmek için:
    python seed_global_medications.py --json "C:/path/to/ilac.json"
"""
import asyncio
import json
import os
import sys
import argparse

# Backend modüllerinin import edilebilmesi için sys.path ayarı
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import engine, Base
from models import GlobalMedication


def _parse_ilac_json(json_path: str) -> list[dict]:
    """
    PHPMyAdmin JSON export'unu parse eder.
    Yapı: [header, database, {type:"table", data:[...]}]
    """
    with open(json_path, encoding="utf-8") as f:
        raw = json.load(f)

    # "data" dizisini taşıyan table kaydını bul
    for entry in raw:
        if isinstance(entry, dict) and entry.get("type") == "table":
            return entry.get("data", [])

    raise ValueError(
        "ilac.json içinde 'type':'table' girişi bulunamadı. "
        "PHPMyAdmin JSON export formatı bekleniyor."
    )


def _to_global_medication(row: dict) -> GlobalMedication:
    def clean(val: str | None, max_len: int | None = None) -> str | None:
        if val is None:
            return None
        val = val.strip()
        if not val:
            return None
        if max_len and len(val) > max_len:
            val = val[:max_len]
        return val

    return GlobalMedication(
        barcode=clean(row.get("barcode"), 50),
        atc_code=clean(row.get("ATC_code"), 20),
        active_ingredient=clean(row.get("Active_Ingredient")),  # Text: sınırsız
        product_name=clean(row.get("Product_Name"), 500) or "Bilinmiyor",
        category_1=clean(row.get("Category_1"), 300),
        category_2=clean(row.get("Category_2"), 300),
        category_3=clean(row.get("Category_3"), 300),
        category_4=clean(row.get("Category_4"), 300),
        category_5=clean(row.get("Category_5"), 300),
        description=clean(row.get("Description")),
    )


async def seed(json_path: str) -> None:
    # Tabloyu sıfırla ve yeniden oluştur (eski schema'yı temizler)
    async with engine.begin() as conn:
        await conn.execute(text("DROP TABLE IF EXISTS global_medications CASCADE"))
        await conn.run_sync(Base.metadata.create_all)

    records = _parse_ilac_json(json_path)
    if not records:
        print("JSON dosyasında kayıt bulunamadı.")
        return

    print(f"Tablo sıfırlandı ve yeniden oluşturuldu.")
    print(f"JSON'dan yüklenecek kayıt sayısı: {len(records)}")

    batch_size = 500
    inserted = 0
    skipped = 0

    async with AsyncSession(engine) as session:
        for i in range(0, len(records), batch_size):
            batch = records[i : i + batch_size]
            objs = []
            for row in batch:
                product_name = (row.get("Product_Name") or "").strip()
                if not product_name:
                    skipped += 1
                    continue
                objs.append(_to_global_medication(row))

            session.add_all(objs)
            await session.flush()
            inserted += len(objs)
            print(f"  {inserted}/{len(records)} kayıt işlendi...")

        await session.commit()

    print(f"\nTamamlandı: {inserted} kayıt eklendi, {skipped} atlandı.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Global ilaç DB seed scripti")
    parser.add_argument(
        "--json",
        default=os.path.join(
            os.path.dirname(__file__), "..", "data", "ilac-json", "ilac.json"
        ),
        help="ilac.json dosyasının yolu",
    )
    args = parser.parse_args()
    json_path = os.path.abspath(args.json)

    if not os.path.exists(json_path):
        print(f"HATA: Dosya bulunamadı: {json_path}")
        sys.exit(1)

    print(f"Kaynak: {json_path}")
    asyncio.run(seed(json_path))
