import sys
sys.path.insert(0, ".")
from routers.medications import _clean_ingredient, _normalize_tr
from services.interaction_engine import interaction_engine, translate_to_turkish

interaction_engine.load()

pairs = [
    ("Karbamazepin", "digoxin"),          # TEGRETOL CR + DIGOXIN (kullanıcının sorunu)
    ("Varfarin Sodyum", "aspirin"),        # tuz formu cleaning testi
    ("warfarin", "aspirin"),               # İngilizce direkt
    ("metoprolol", "verapamil"),           # bilinen etkileşim
    ("atorvastatin", "clarithromycin"),    # bilinen etkileşim
    ("lisinopril", "ibuprofen"),           # bilinen etkileşim
    ("amoksisilin", "metotreksat"),        # Türkçe test
]

print(f"{'İlaç A':30} {'İlaç B':30} {'Clean A':18} {'Clean B':18} {'Sonuç':14} Risk")
print("-" * 120)
for a, b in pairs:
    ca = _clean_ingredient(_normalize_tr(a))
    cb = _clean_ingredient(_normalize_tr(b))
    hit = interaction_engine.lookup(ca, cb)
    status = hit["matched_by"] if hit else "YOK"
    risk   = hit["risk_level"] if hit else "-"
    desc   = translate_to_turkish(hit["description"])[:60] if hit else ""
    print(f"{a:30} {b:30} {ca:18} {cb:18} {status:14} {risk}  {desc}")
