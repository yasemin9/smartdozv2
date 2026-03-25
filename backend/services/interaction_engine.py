"""
SmartDoz - Modül 3: İlaç Etkileşim Motoru

Uygulama başladığında CSV'yi pandas DataFrame olarak belleğe yükler.
Her istek için DB'ye gitmez — bellek içi arama yapar.

Lookup zinciri (Algoritma 2 + 3):
  1. Tam eşleşme  → drug1/drug2 normalize metinleri tam olarak eşleşir
  2. Levenshtein  → rapidfuzz token_set_ratio ile en yakın isim (Algoritma 3)
"""
from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Optional

import pandas as pd
from rapidfuzz import fuzz, process

logger = logging.getLogger(__name__)

# CSV varsayılan yol adayları
_CSV_CANDIDATES = [
    Path(__file__).resolve().parents[2] / "data" / "db_drug_interactions.csv",
    Path(__file__).resolve().parents[2]
    / "data"
    / "ilac-json"
    / "db_drug_interactions.csv"
    / "db_drug_interactions.csv",
]

# Türkçe → ASCII normalizasyon tablosu
_TR_CHAR_MAP = str.maketrans(
    "çşğüöıİĞŞÇÜÖ",
    "csguoiIGSCUO",
)

# Yüksek riskli açıklama anahtar kelimeleri
_HIGH_RISK_KEYWORDS = frozenset([
    "severe", "major", "serious", "fatal", "life-threatening",
    "contraindicated", "avoid", "do not use", "significant",
    "clinically significant",
])

# Düşük riskli
_LOW_RISK_KEYWORDS = frozenset([
    "minor", "minimal", "negligible", "unlikely",
])


def _normalize(text: str) -> str:
    """Türkçe karakterleri ASCII'ye dönüştürür, küçük harfe çevirir, fazla boşlukları temizler."""
    if not text:
        return ""
    return text.translate(_TR_CHAR_MAP).lower().strip()


def _parse_risk_level(description: str) -> str:
    """
    Açıklama metninden risk seviyesi çıkarır.
    Döner: YUKSEK | ORTA | DUSUK
    """
    d = description.lower()
    if any(kw in d for kw in _HIGH_RISK_KEYWORDS):
        return "YUKSEK"
    if any(kw in d for kw in _LOW_RISK_KEYWORDS):
        return "DUSUK"
    return "ORTA"


# ──────────────────────────────────────────────────────────────────────────────
# Türkçe çeviri kalıpları — description cümlelerini Türkçeye yaklaştırır
# ──────────────────────────────────────────────────────────────────────────────
_TR_REPLACEMENTS = [
    ("may increase the photosensitizing activities of", "fotosensitivite etkisini artırabilir:"),
    ("may increase the cardiotoxic activities of", "kardiyotoksik etkilerini artırabilir:"),
    ("may decrease the cardiotoxic activities of", "kardiyotoksik etkilerini azaltabilir:"),
    ("may increase the neurotoxic activities of", "nörotoksik etkilerini artırabilir:"),
    ("may increase the nephrotoxic activities of", "nefrotoksik etkilerini artırabilir:"),
    ("may increase the hepatotoxic activities of", "hepatotoksik etkilerini artırabilir:"),
    ("may increase the QTc-prolonging activities of", "QTc uzamasını artırabilir:"),
    ("may increase the hypoglycemic activities of", "hipoglisemik etkilerini artırabilir:"),
    ("may increase the hypotensive activities of", "hipotansif etkilerini artırabilir:"),
    ("may increase the anticoagulant activities of", "antikoagülan etkilerini artırabilir:"),
    ("may decrease the anticoagulant activities of", "antikoagülan etkilerini azaltabilir:"),
    ("may increase the serum concentration of", "serum konsantrasyonunu artırabilir:"),
    ("may decrease the serum concentration of", "serum konsantrasyonunu azaltabilir:"),
    ("may increase the central nervous system depressant", "MSS baskılayıcı etkilerini artırabilir:"),
    ("may increase the sedative activities of", "sedatif etkilerini artırabilir:"),
    ("may increase the bleeding risk", "kanama riskini artırabilir"),
    ("may increase the risk of bleeding", "kanama riskini artırabilir"),
    ("can increase the risk or severity of", "riski veya şiddetini artırabilir:"),
    ("The metabolism of", "Metabolizması"),
    ("can be increased when combined with", "ile birlikte kullanıldığında artabilir."),
    ("can be decreased when combined with", "ile birlikte kullanıldığında azalabilir."),
    ("can be increased when it is combined with", "ile birlikte kullanıldığında artabilir."),
    ("can be decreased when it is combined with", "ile birlikte kullanıldığında azalabilir."),
    ("The serum concentration of", "Serum konsantrasyonu"),
    ("The risk or severity of adverse effects can be increased when", "Advers etki riski artabilir:"),
    ("The risk or severity of ", "Riski/şiddeti artabilir — "),
    ("is combined with", "ile birlikte kullanıldığında"),
    ("when used in combination with", "ile kombinasyonda"),
    ("concomitant use", "eş zamanlı kullanım"),
    ("may potentiate", "etkisini güçlendirebilir"),
    ("may inhibit", "inhibe edebilir"),
    ("may reduce", "azaltabilir"),
    ("may enhance", "artırabilir"),
    ("adverse effects", "advers etkiler"),
    ("side effects", "yan etkiler"),
    ("serum concentration", "serum konsantrasyonu"),
    ("blood pressure", "kan basıncı"),
    ("heart rate", "kalp hızı"),
]


def translate_to_turkish(description: str) -> str:
    """İngilizce etkileşim açıklamasını Türkçeye çevirir."""
    d = description.strip()
    for en, tr in _TR_REPLACEMENTS:
        d = d.replace(en, tr)
    if d == description.strip():
        return f"Potansiyel etkileşim: {description.strip()}"
    return d


# ──────────────────────────────────────────────────────────────────────────────
# Ana Motor
# ──────────────────────────────────────────────────────────────────────────────

class InteractionEngine:
    """
    Bellek içi ilaç etkileşim motoru.
    Uygulama başlangıcında bir kez yüklenir (lifespan hook).
    Thread-safe okuma sağlar; yazma yoktur.
    """

    def __init__(self) -> None:
        self._df: Optional[pd.DataFrame] = None
        self._drug_names: list[str] = []
        self._loaded = False

    # ── Yükleme ──────────────────────────────────────────────────────────────

    def load(self, csv_path: Optional[str | Path] = None) -> None:
        """
        CSV dosyasını yükler ve normalize eder.
        csv_path belirtilmezse varsayılan aday listesini dener.
        """
        path = Path(csv_path) if csv_path else self._find_csv()
        try:
            df = pd.read_csv(path, dtype=str).fillna("")

            # Sütun adlarını standartlaştır
            df.columns = [c.strip() for c in df.columns]
            col_map = {}
            for col in df.columns:
                lc = col.lower().replace(" ", "")
                if "drug1" in lc or col.lower() == "drug 1":
                    col_map[col] = "drug1"
                elif "drug2" in lc or col.lower() == "drug 2":
                    col_map[col] = "drug2"
                elif "description" in lc or "interaction" in lc:
                    col_map[col] = "description"
            df = df.rename(columns=col_map)

            if not {"drug1", "drug2", "description"}.issubset(df.columns):
                raise ValueError(f"CSV'de beklenen sütunlar bulunamadı. Mevcut: {list(df.columns)}")

            df["drug1_norm"] = df["drug1"].map(_normalize)
            df["drug2_norm"] = df["drug2"].map(_normalize)

            # Boş satırları at
            df = df[(df["drug1_norm"] != "") & (df["drug2_norm"] != "")].reset_index(drop=True)

            self._df = df
            # Levenshtein arama için tüm benzersiz normalize isimler
            self._drug_names = list(
                set(df["drug1_norm"].tolist() + df["drug2_norm"].tolist())
            )
            self._loaded = True
            logger.info(
                f"InteractionEngine yüklendi: {len(df):,} etkileşim, "
                f"{len(self._drug_names):,} benzersiz ilaç adı."
            )

        except Exception as exc:
            logger.error(f"InteractionEngine yükleme hatası: {exc}")
            raise

    @staticmethod
    def _find_csv() -> Path:
        for candidate in _CSV_CANDIDATES:
            if candidate.exists() and candidate.is_file():
                return candidate
        raise FileNotFoundError(
            "db_drug_interactions.csv bulunamadı. "
            "--csv parametresi ile tam yolu belirtin."
        )

    @property
    def is_loaded(self) -> bool:
        return self._loaded

    # ── Arama ────────────────────────────────────────────────────────────────

    def lookup(
        self,
        ingredient_a: str,
        ingredient_b: str,
        levenshtein_threshold: int = 78,
    ) -> dict | None:
        """
        ingredient_a ile ingredient_b arasındaki etkileşimi arar.

        Dönüş:
            {description, risk_level, matched_by, confidence_score}
            veya etkileşim yoksa None.

        matched_by değerleri:
            EXACT        — tam string eşleşmesi
            LEVENSHTEIN  — Algoritma 3 fuzzy eşleşmesi
        """
        if not self._loaded or self._df is None:
            logger.warning("InteractionEngine yüklenmemiş; lookup atlanıyor.")
            return None

        a = _normalize(ingredient_a)
        b = _normalize(ingredient_b)

        if not a or not b:
            return None

        # ── 1. Tam eşleşme ────────────────────────────────────────────────
        hit = self._exact_lookup(a, b)
        if hit:
            return {**hit, "matched_by": "EXACT", "confidence_score": 1.0}

        # ── 2. Levenshtein (Algoritma 3) ──────────────────────────────────
        best_a = self._levenshtein_best(a, levenshtein_threshold)
        best_b = self._levenshtein_best(b, levenshtein_threshold)

        if best_a and best_b:
            hit2 = self._exact_lookup(best_a[0], best_b[0])
            if hit2:
                confidence = round(min(best_a[1], best_b[1]) / 100.0, 2)
                return {**hit2, "matched_by": "LEVENSHTEIN", "confidence_score": confidence}

        return None

    def _exact_lookup(self, a: str, b: str) -> dict | None:
        """DataFrame'de tam normalize eşleşme arar."""
        mask = (
            ((self._df["drug1_norm"] == a) & (self._df["drug2_norm"] == b))
            | ((self._df["drug1_norm"] == b) & (self._df["drug2_norm"] == a))
        )
        hits = self._df[mask]
        if hits.empty:
            return None
        row = hits.iloc[0]
        desc = row["description"]
        return {
            "description": desc,
            "risk_level": _parse_risk_level(desc),
        }

    def _levenshtein_best(
        self, name: str, threshold: int
    ) -> tuple[str, float] | None:
        """rapidfuzz token_set_ratio ile en yakın eşleşmeyi döndürür."""
        if not name or not self._drug_names:
            return None
        result = process.extractOne(
            name,
            self._drug_names,
            scorer=fuzz.token_set_ratio,
            score_cutoff=threshold,
        )
        return (result[0], result[1]) if result else None


# Uygulama genelinde tek örnek (Singleton)
interaction_engine = InteractionEngine()
