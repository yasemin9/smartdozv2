"""
SmartDoz - Modül 3
Drug interaction CSV dosyasını PostgreSQL'e asenkron olarak aktarır.

Hedef tablo adı: DrugInteractions
Kolonlar: drug1, drug2, description
İndeksler: drug1 ve drug2 üzerinde B-Tree

Kullanım:
    python import_interactions.py
    python import_interactions.py --csv "C:/path/to/db_drug_interactions.csv" --batch-size 5000
"""

from __future__ import annotations

import argparse
import asyncio
import csv
from pathlib import Path
from typing import Iterable

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import engine


DEFAULT_PATH_CANDIDATES = [
    Path(__file__).resolve().parents[1] / "data" / "db_drug_interactions.csv",
    Path(__file__).resolve().parents[1]
    / "data"
    / "ilac-json"
    / "db_drug_interactions.csv"
    / "db_drug_interactions.csv",
]


def find_default_csv_path() -> Path:
    for candidate in DEFAULT_PATH_CANDIDATES:
        if candidate.exists() and candidate.is_file():
            return candidate
    raise FileNotFoundError(
        "db_drug_interactions.csv bulunamadı. --csv ile tam yol verin."
    )


def count_data_rows(csv_path: Path) -> int:
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        # Header satırını düş
        return max(sum(1 for _ in f) - 1, 0)


def normalize_row(row: dict[str, str]) -> tuple[str, str, str] | None:
    drug1 = (row.get("Drug 1") or "").strip()
    drug2 = (row.get("Drug 2") or "").strip()
    description = (row.get("Interaction Description") or "").strip()

    if not drug1 or not drug2 or not description:
        return None
    return drug1, drug2, description


def iter_csv_rows(csv_path: Path) -> Iterable[tuple[str, str, str]]:
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            parsed = normalize_row(row)
            if parsed is not None:
                yield parsed


def render_progress(done: int, total: int, width: int = 36) -> str:
    if total <= 0:
        return "[" + ("-" * width) + "] 0.00%"
    ratio = min(max(done / total, 0.0), 1.0)
    filled = int(ratio * width)
    bar = "#" * filled + "-" * (width - filled)
    percent = ratio * 100
    return f"[{bar}] {percent:6.2f}% ({done}/{total})"


async def ensure_table_and_indexes(session: AsyncSession) -> None:
    # Eski veriyle çakışma olmasın diye import her seferinde tabloyu sıfırlar.
    await session.execute(text('DROP TABLE IF EXISTS "DrugInteractions"'))

    await session.execute(
        text(
            '''
            CREATE TABLE "DrugInteractions" (
                id BIGSERIAL PRIMARY KEY,
                drug1 TEXT NOT NULL,
                drug2 TEXT NOT NULL,
                description TEXT NOT NULL
            )
            '''
        )
    )

    await session.execute(
        text(
            'CREATE INDEX IF NOT EXISTS idx_drug_interactions_drug1 '
            'ON "DrugInteractions" USING BTREE (drug1)'
        )
    )
    await session.execute(
        text(
            'CREATE INDEX IF NOT EXISTS idx_drug_interactions_drug2 '
            'ON "DrugInteractions" USING BTREE (drug2)'
        )
    )


async def import_csv(csv_path: Path, batch_size: int) -> None:
    total_rows = count_data_rows(csv_path)
    print(f"Kaynak CSV: {csv_path}")
    print(f"Toplam satır: {total_rows}")
    print("Import başlatılıyor...")

    inserted = 0
    batch: list[dict[str, str]] = []

    insert_sql = text(
        '''
        INSERT INTO "DrugInteractions" (drug1, drug2, description)
        VALUES (:drug1, :drug2, :description)
        '''
    )

    async with AsyncSession(engine) as session:
        await ensure_table_and_indexes(session)
        await session.commit()

    async with AsyncSession(engine) as session:
        for drug1, drug2, description in iter_csv_rows(csv_path):
            batch.append(
                {
                    "drug1": drug1,
                    "drug2": drug2,
                    "description": description,
                }
            )

            if len(batch) >= batch_size:
                await session.execute(insert_sql, batch)
                await session.commit()
                inserted += len(batch)
                batch.clear()
                print("\r" + render_progress(inserted, total_rows), end="", flush=True)

        if batch:
            await session.execute(insert_sql, batch)
            await session.commit()
            inserted += len(batch)
            batch.clear()
            print("\r" + render_progress(inserted, total_rows), end="", flush=True)

        count_result = await session.execute(
            text('SELECT COUNT(*) FROM "DrugInteractions"')
        )
        db_count = int(count_result.scalar_one())

    print()
    print(f"Tamamlandı. Veritabanına yazılan kayıt: {db_count}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Drug interaction CSV verisini PostgreSQL'e import eder"
    )
    parser.add_argument(
        "--csv",
        type=str,
        default=None,
        help="CSV dosya yolu (varsayılan: data altındaki db_drug_interactions.csv)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=5000,
        help="Her committe insert edilecek satır sayısı (varsayılan: 5000)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.batch_size <= 0:
        raise ValueError("batch-size pozitif olmalı")

    csv_path = Path(args.csv).resolve() if args.csv else find_default_csv_path()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV dosyası bulunamadı: {csv_path}")

    asyncio.run(import_csv(csv_path, batch_size=args.batch_size))


if __name__ == "__main__":
    main()
