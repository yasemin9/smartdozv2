import asyncio, sys; sys.path.insert(0, '.')
from sqlalchemy import text
from database import engine

SQL = """
SELECT similarity(LOWER(drug1), :a) as s1, similarity(LOWER(drug2), :b) as s2, drug1, drug2
FROM "DrugInteractions"
WHERE LOWER(drug1) LIKE :ap
LIMIT 3
"""

async def main():
    async with engine.connect() as conn:
        tests = [
            ('karbamazepin', 'digoxin', 'karbama'),
            ('varfarin sodyum', 'clopidogrel', 'warfar'),
            ('warfarin', 'clopidogrel', 'warfar'),
        ]
        for a, b, prefix in tests:
            r = await conn.execute(text(SQL), {'a': a, 'b': b, 'ap': f'%{prefix}%'})
            rows = r.fetchall()
            print(f"Aranan: {a!r} + {b!r}")
            for row in rows:
                print(f"  drug1={row[2]!r} s1={row[0]:.3f}  drug2={row[3]!r} s2={row[1]:.3f}")
            print()

asyncio.run(main())
