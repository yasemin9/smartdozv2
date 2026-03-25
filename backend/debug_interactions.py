"""Mevcut ilaçların active_ingredient durumunu kontrol eder ve token eşleşmesini simüle eder."""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from sqlalchemy import text
from database import engine
from routers.medications import _normalize_tr, _ingredient_tokens, _resolve_active_ingredient
from models import Medication

SQL_MEDS = """
SELECT id, name, active_ingredient, atc_code
FROM medications
ORDER BY id DESC LIMIT 20
"""

SQL_DRUG_CHECK = """
SELECT description
FROM "DrugInteractions"
WHERE
    (LOWER(drug1) = :a AND LOWER(drug2) = :b)
    OR (LOWER(drug1) = :b AND LOWER(drug2) = :a)
LIMIT 1
"""

SQL_SIM_CHECK = """
SELECT description, similarity(LOWER(drug1), :a) as s1, similarity(LOWER(drug2), :b) as s2
FROM "DrugInteractions"
WHERE
    (similarity(LOWER(drug1), :a) > 0.5 AND similarity(LOWER(drug2), :b) > 0.5)
    OR (similarity(LOWER(drug1), :b) > 0.5 AND similarity(LOWER(drug2), :a) > 0.5)
ORDER BY GREATEST(
    similarity(LOWER(drug1), :a) * similarity(LOWER(drug2), :b),
    similarity(LOWER(drug1), :b) * similarity(LOWER(drug2), :a)
) DESC
LIMIT 3
"""


async def main():
    async with engine.connect() as conn:
        print("=== MEVCUT İLAÇLAR ===")
        rows = (await conn.execute(text(SQL_MEDS))).fetchall()
        for r in rows:
            ai = r[2] or "(BOŞ)"
            atc = r[3] or "(BOŞ)"
            tokens = _ingredient_tokens(r[2])
            print(f"  ID={r[0]} | {r[1]}")
            print(f"     active_ingredient: {ai}  |  atc: {atc}")
            print(f"     tokens: {tokens}")
        
        print()
        print("=== TOKEN ÇİFT TESTİ ===")
        # Tüm ilaç çiftlerini test et
        if len(rows) >= 2:
            for i in range(len(rows)):
                for j in range(i+1, len(rows)):
                    t1 = _ingredient_tokens(rows[i][2])
                    t2 = _ingredient_tokens(rows[j][2])
                    if not t1 or not t2:
                        print(f"  {rows[i][1][:20]} + {rows[j][1][:20]}: TOKEN YOK (boş active_ingredient)")
                        continue
                    for a in t1:
                        for b in t2:
                            # Exact
                            res = await conn.execute(text(SQL_DRUG_CHECK), {"a": a, "b": b})
                            hit = res.scalar_one_or_none()
                            if hit:
                                print(f"  EXACT MATCH: {a!r} + {b!r} -> {hit[:60]}")
                            else:
                                # Similarity
                                res2 = await conn.execute(text(SQL_SIM_CHECK), {"a": a, "b": b})
                                hits2 = res2.fetchall()
                                if hits2:
                                    print(f"  SIM MATCH ({hits2[0][1]:.2f},{hits2[0][2]:.2f}): {a!r} + {b!r} -> {hits2[0][0][:60]}")
                                else:
                                    print(f"  YOK: {a!r} + {b!r}")

asyncio.run(main())
