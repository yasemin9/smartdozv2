import json

with open('data/ilac-json/ilac.json', encoding='utf-8') as f:
    data = json.load(f)

rows = data[2]['data']
print("Toplam ilac:", len(rows))
print("Ilk kayit:", rows[0])
print()

# Warfarin ara
hits = [r for r in rows if 'warfarin' in str(r).lower()]
print("Warfarin iceren:", len(hits))
for h in hits[:3]:
    print(h)
