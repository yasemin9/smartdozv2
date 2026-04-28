"""
SmartDoz - Modül 5: Yapay Zeka Tabanlı İlaç Bilgisi Özetleme Servisi

Rapor Bölüm 4.3.5 — Teknik İş Akışı:
  1. Veri Çekme     : DB (global_medications.description) veya ilac.json
  2. Metin Bölütleme: Prospektüs → (Endikasyon, Yan Etkiler, Dozaj, Uyarılar)
  3. NLP İşleme     : Soyutlayıcı özetleme (Hugging Face / kural tabanlı fallback)
  4. NER            : Dozaj bilgileri ve kritik yan etkiler etiketlenir
  5. Güvenlik       : AI sorumluluk reddi eklenir

NLP Öncelik Sırası (performans & güvenilirlik):
  1. csebuetnlp/mT5_multilingual_XLSum (Türkçe destekli, 1.2GB)
  2. sshleifer/distilbart-cnn-12-6 (İngilizce ağırlıklı, 306MB)
  3. Kural tabanlı çıkarımsal özetleme (fallback — model yoksa)

Güvenlik Notu: Üretilen özetler tıbbi tavsiye değildir.
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────────────────────
# Veri Yapıları
# ──────────────────────────────────────────────────────────────────────────────

AI_DISCLAIMER = (
    "⚠️ Bu bir yapay zeka özetidir. İlaç kullanımına dair "
    "nihai karar mutlaka doktorunuza veya eczacınıza danışılarak alınmalıdır."
)

DISCLAIMER_SHORT = (
    "⚠️ Bu bir yapay zeka özetidir. Kesin bilgi için doktorunuza danışın."
)

# ── Eksik/Boş Prospektüs Marker & Fallback Metni ─────────────────────────────
# Veritabanından gelen description 'İkinci siteye ait içerik bulunamadı.'
# ifadesini içeriyorsa bu fallback metin kullanıcıya gösterilir.
_MISSING_CONTENT_MARKER = "İkinci siteye ait içerik bulunamadı."

_PROSPECTUS_UNAVAILABLE = (
    "Bu ilaca ait detaylı prospektüs bilgisi şu an sistemimizde güncellenmektedir. "
    "En doğru bilgi için lütfen doktorunuza veya eczacınıza danışınız."
)


@dataclass
class MedicationSummary:
    """Özetlenmiş ilaç bilgisi."""

    product_name: str
    active_ingredient: Optional[str]
    atc_code: Optional[str]
    category: Optional[str]

    # NLP ile çıkarılan bölümler
    indication: str = ""          # Ne için kullanılır?
    side_effects: str = ""        # Yan etkiler
    dosage: str = ""              # Nasıl / ne kadar kullanılır?
    warnings: str = ""            # Dikkat edilmesi gerekenler / kontraendikasyon

    # NER etiketleri
    dosage_entities: list[str] = field(default_factory=list)
    critical_side_effects: list[str] = field(default_factory=list)

    # Meta
    summary_method: str = "rule_based"  # "transformers" | "rule_based" | "llm"
    disclaimer: str = AI_DISCLAIMER

    # ── Yapılandırılmış 3-Kategori Özet (yeni UI için) ────────────────────────
    temel_faydasi: list[str] = field(default_factory=list)      # 🌟 Ne için kullanılır?
    kullanim_sekli: list[str] = field(default_factory=list)     # 🥄 Nasıl kullanılır?
    dikkat_edilecekler: list[str] = field(default_factory=list) # ⚠️ Dikkat edilecekler


# ──────────────────────────────────────────────────────────────────────────────
# Bölüm Kalıpları (Türkçe Prospektüs)
# ──────────────────────────────────────────────────────────────────────────────

# Her bölüm için olası başlık kalıpları (Türkçe prospektüs formatı)
_SEC_PATTERNS: dict[str, list[str]] = {
    "indication": [
        r"ne\s+i[cç]in\s+kullan[ıi]l[ıi]r",
        r"end[iı]kasyon",
        r"nedir\s+ve\s+ne\s+i[cç]in",
        r"hangi\s+hastal[ıi]klar[ıi]n\s+tedavisinde",
        r"1\.\s+\w+\s+ned[iı]r",
    ],
    "warnings": [
        r"kullanmadan\s+[öo]nce\s+dikkat",
        r"dikkatl[iı]\s+kullan[ıi]n[ıi]z",
        r"kullanmay[ıi]n[ıi]z",
        r"kontrendikasyon",
        r"2\.\s+\w+\s+kullanmadan",
        r"uyar[ıi]lar",
        r"sakl[ıi]nmas[ıi]\s+gereken\s+durumlar",
    ],
    "dosage": [
        r"nas[ıi]l\s+kullan[ıi]l[ıi]r",
        r"doz[ıu]?.*?uygulanmas[ıi]",
        r"kullan[ıi]m[ıi]\s+ve\s+doz",
        r"3\.\s+\w+\s+nas[ıi]l",
        r"uygun\s+kullan[ıi]m\s+ve\s+doz",
        r"uygulama\s+yolu",
    ],
    "side_effects": [
        r"yan\s+etkiler",
        r"olas[ıi]\s+yan\s+etk",
        r"4\.\s+olas[ıi]\s+yan",
        r"istenmeyen\s+etkiler",
        r"g[öo]r[üu]lebilecek\s+istenmeyen",
    ],
}

# Kritik yan etkiler için NER kalıpları
_CRITICAL_NER: list[tuple[str, str]] = [
    (r"anafilaksi", "Anafilaksi (ciddi alerjik reaksiyon)"),
    (r"anjiy[oö][öo]dem", "Anjiyoödem (yüz/boğaz şişmesi)"),
    (r"steven[s']?\s*johnson", "Stevens-Johnson sendromu"),
    (r"sar[ıi]l[ıi]k|cildin\s+sararmas[ıi]", "Sarılık (karaciğer bulgusu)"),
    (r"intihar", "İntihar düşüncesi"),
    (r"nefes\s+(alma[yd]a\s+)?zorluk|solunum\s+güçlüğü", "Solunum güçlüğü"),
    (r"kalp\s+(durmas[ıi]|ritimsizliği|kriz)", "Kardiyak olay"),
    (r"koma|bilin[cç]\s+kayb[ıi]", "Bilinç kaybı / koma"),
    (r"felç|inmesi?", "Felç (inme)"),
    (r"kan[ıi]n[ıi]n?\s+pıhtılaşmas[ıi]|tromboz", "Tromboz"),
]

# Dozaj NER: sayı + birim + zaman ifadeleri
_DOSAGE_NER_PATTERN = re.compile(
    r"""
    (?:
        \d+(?:[.,]\d+)?            # sayı
        \s*
        (?:mg|mcg|mg/ml|iu|ünite|ml|tablet|kapsül|damla)?  # birim
        \s*
        (?:/gün|/hafta|/ay|günde|haftada|sabah|akşam|öğlen)?  # sıklık
        \b
    )
    """,
    re.VERBOSE | re.IGNORECASE,
)

# ──────────────────────────────────────────────────────────────────────────────
# Yardımcı: Metin Temizleme
# ──────────────────────────────────────────────────────────────────────────────

def _clean_text(text: str) -> str:
    """Ham prospektüs metnini temizler."""
    # Satır sonu normalizasyonu
    text = re.sub(r"\r\n|\r", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    # Madde işaretleri
    text = re.sub(r"^[•·\-–—]\s*", "", text, flags=re.MULTILINE)
    # Sayfa numaraları
    text = re.sub(r"\n\s*\d+\s*\n", "\n", text)
    # Daire içi harfler ve emoji (🅄 gibi circled letters, emoji blokları)
    text = re.sub(r"[\u2460-\u2473\u24B6-\u24E9\U0001F000-\U0001F9FF\u2600-\u27BF]", "", text)
    # ® ™ © gibi semboller
    text = re.sub(r"[\u00AE\u2122\u00A9\u2117]", "", text)
    return text.strip()


def _split_sentences(text: str, max_count: int = 5) -> str:
    """Metni cümlelere böler ve ilk N cümleyi döner."""
    # Türkçe cümle sonu: büyük harf önlemine göre
    sentences = re.split(r"(?<=[.!?])\s+(?=[A-ZÇĞİÖŞÜA-Z])", text)
    unique = []
    seen: set[str] = set()
    for s in sentences:
        s = s.strip()
        if len(s) > 20 and s not in seen:
            seen.add(s)
            unique.append(s)
    return " ".join(unique[:max_count])


# ──────────────────────────────────────────────────────────────────────────────
# Bölüm Çıkarımı
# ──────────────────────────────────────────────────────────────────────────────

# Bilinen konu dışı bölüm başlıkları — bu kalıpla eşleşen bir satır
# görüldüğünde mevcut bölüm kaydetme durdurulur.
_STOP_PATTERNS: list[str] = [
    r"saklama\s+ko[şs]ullar",
    r"saklanmas[ıi]\s+(gereken|ko[şs]ul|[şs]artlar)",
    r"nas[ıi]l\s+saklan",        # "nasıl saklanır" başlığı
    r"raf\s+ömrü",
    r"ambalaj(\s+bilgi|ının|ı)?\s*:",
    r"ruhsat\s+(sahibi|numaras[ıi])",
    r"üretici\s+firma",
    r"ithalatç[ıi]",
    r"farmakokinetik",
    r"farmakodinami",
    r"diğer\s+bilgiler",
    r"^\d\.\s+\w{3,}.*saklan",  # "5. X nasıl saklanır"
    r"^6\.\s+\w",
    r"^7\.\s+\w",
    r"^8\.\s+\w",
]
_STOP_RE = re.compile("|".join(_STOP_PATTERNS), re.IGNORECASE)


def _extract_sections(text: str) -> dict[str, str]:
    """
    Prospektüs metnini semantik bölümlere ayırır.
    Türkçe başlık kalıplarına göre metin blokları bulunur.
    Konu dışı bölümler (saklama, ruhsat vb.) görüldüğünde durdurulur.

    Returns:
        {indication, warnings, dosage, side_effects} → ham metin blokları
    """
    sections: dict[str, str] = {k: "" for k in _SEC_PATTERNS}

    lines = text.split("\n")
    current_section: Optional[str] = None
    buffer: list[str] = []

    def _flush():
        if current_section and buffer:
            combined = " ".join(buffer).strip()
            if sections[current_section]:
                sections[current_section] += " " + combined
            else:
                sections[current_section] = combined

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        # Durdurma kalıpları kontrolü — mevcut bölüm bitirilir
        if current_section and _STOP_RE.search(stripped):
            _flush()
            current_section = None
            buffer = []
            continue

        matched_section: Optional[str] = None
        for sec_name, patterns in _SEC_PATTERNS.items():
            for pat in patterns:
                if re.search(pat, stripped, re.IGNORECASE):
                    matched_section = sec_name
                    break
            if matched_section:
                break

        if matched_section:
            _flush()
            current_section = matched_section
            buffer = []
        elif current_section:
            buffer.append(stripped)

    _flush()
    return sections


# ──────────────────────────────────────────────────────────────────────────────
# Jargon → Günlük Dil Sözlüğü (stil transferi)
# ──────────────────────────────────────────────────────────────────────────────

_JARGON_MAP: list[tuple[str, str]] = [
    (r"\bkontrendikasyon\b", "kullanılmaması gereken durumlar"),
    (r"\bendikasyon\b", "kullanım amacı"),
    (r"\bhipertansiyon\b", "yüksek tansiyon"),
    (r"\bhipotansiyon\b", "düşük tansiyon"),
    (r"\btaşikardi\b", "hızlı kalp atışı"),
    (r"\bbradikardi\b", "yavaş kalp atışı"),
    (r"\bnefropati\b", "böbrek hasarı"),
    (r"\bnöropati\b", "sinir hasarı"),
    (r"\bgastrointestinal\b", "mide-bağırsak"),
    (r"\bantibiyotik\b(?!\s+direnci)", "bakteri öldürücü ilaç"),
    (r"\bantihipertansif\b", "tansiyon düşürücü"),
    (r"\bantikoagülan\b", "kan sulandırıcı"),
    (r"\banalj[eé]zik\b", "ağrı kesici"),
    (r"\bantipretik\b", "ateş düşürücü"),
    (r"\btakipne\b", "hızlı nefes alma"),
    (r"\bdispne\b", "nefes darlığı"),
    (r"\bhipoglisemi\b", "düşük kan şekeri"),
    (r"\bhiperkalsemi\b", "yüksek kan kalsiyumu"),
    (r"\bhepatotoksisite\b", "karaciğer zararı"),
    (r"\bnefrotoksisite\b", "böbrek zararı"),
    (r"\bprofilaksi\b", "koruyucu tedavi"),
    (r"\btitrasyon\b", "doz ayarlaması"),
    (r"\boral\b", "ağız yoluyla"),
    (r"\bintravenöz\b", "damar içine"),
    (r"\bintramüsküler\b", "kas içine"),
    (r"\bsubkütan\b", "deri altına"),
    (r"\bplazma\b", "kan sıvısı"),
    (r"\bmetabolizma\b", "vücutta işlenme"),
    (r"\bklirensi?\b", "vücuttan atılma hızı"),
    (r"\bkroniK\b", "uzun süreli"),
    (r"\bakut\b", "ani başlayan"),
    (r"\bprolonge\b", "uzatılmış"),
    (r"\bsedasyon\b", "uyuşukluk/uyku hali"),
    (r"\bertitemi\b", "kızarıklık"),
    (r"\bürtiker\b", "kurdeşen"),
    (r"\bpruritus\b", "kaşıntı"),
    (r"\bfibromiyalji\b", "yaygın kas-eklem ağrısı"),
    (r"\banksiyete\b", "kaygı bozukluğu"),
    (r"\binsomni\b", "uyuyamama"),
    (r"\bvertigo\b", "baş dönmesi (denge bozukluğu)"),
    (r"\btinnitus\b", "kulak çınlaması"),
]


def _plain_language(text: str) -> str:
    """Tıbbi jargonu günlük Türkçeye çevirir (stil transferi)."""
    for pattern, replacement in _JARGON_MAP:
        text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
    return text


# ──────────────────────────────────────────────────────────────────────────────
# NER: Dozaj & Kritik Yan Etkiler
# ──────────────────────────────────────────────────────────────────────────────

def _extract_dosage_entities(text: str) -> list[str]:
    """Dozaj ifadelerini tanır."""
    raw = _DOSAGE_NER_PATTERN.findall(text)
    # Temizle: çok kısa ve tekrar edenleri at
    seen: set[str] = set()
    result: list[str] = []
    for item in raw:
        normalized = item.strip().lower()
        if len(normalized) >= 4 and normalized not in seen:
            seen.add(normalized)
            result.append(item.strip())
    return result[:10]  # en fazla 10 entite


def _extract_critical_side_effects(text: str) -> list[str]:
    """Kritik yan etkileri NER ile tespit eder."""
    found: list[str] = []
    for pattern, label in _CRITICAL_NER:
        if re.search(pattern, text, re.IGNORECASE):
            found.append(label)
    return found


# ──────────────────────────────────────────────────────────────────────────────
# Hugging Face Transformers (Opsiyonel, Lazy Load)
# ──────────────────────────────────────────────────────────────────────────────

_pipeline_cache: dict[str, object] = {}


def _get_summarizer():
    """
    Hugging Face özetleme pipeline'ını lazy olarak yükler.
    Önce Türkçe destekli model dener, başarısız olursa distilBART.
    Tüm model yüklemeleri başarısız olursa None döner.
    """
    if "summarizer" in _pipeline_cache:
        return _pipeline_cache["summarizer"]

    try:
        from transformers import pipeline  # type: ignore
    except ImportError:
        logger.info("transformers kütüphanesi yüklü değil, kural tabanlı özetleme kullanılıyor.")
        _pipeline_cache["summarizer"] = None
        return None

    model_candidates = [
        "csebuetnlp/mT5_multilingual_XLSum",  # Türkçe dahil çok dilli (1.2GB)
        "sshleifer/distilbart-cnn-12-6",       # Hızlı distil-BART (306MB)
    ]

    for model_name in model_candidates:
        try:
            logger.info(f"Hugging Face modeli yükleniyor: {model_name}")
            summarizer = pipeline(
                "summarization",
                model=model_name,
                tokenizer=model_name,
                truncation=True,
                max_length=256,
                min_length=40,
            )
            _pipeline_cache["summarizer"] = summarizer
            logger.info(f"Model başarıyla yüklendi: {model_name}")
            return summarizer
        except Exception as exc:
            logger.warning(f"{model_name} yüklenemedi: {exc}")
            continue

    logger.warning("Tüm Hugging Face modelleri başarısız — kural tabanlı fallback aktif.")
    _pipeline_cache["summarizer"] = None
    return None


def _hf_summarize(text: str, max_length: int = 120, min_length: int = 30) -> Optional[str]:
    """Hugging Face ile metni özetler. Başarısız olursa None döner."""
    if not text or len(text.split()) < 30:
        return None

    summarizer = _get_summarizer()
    if summarizer is None:
        return None

    try:
        # Modelin maksimum token limitine göre metni kırp (yaklaşık 1024 token ≈ 700 kelime)
        words = text.split()
        if len(words) > 700:
            text = " ".join(words[:700])

        result = summarizer(
            text,
            max_length=max_length,
            min_length=min_length,
            do_sample=False,
        )
        return result[0]["summary_text"]  # type: ignore[index]
    except Exception as exc:
        logger.warning(f"Hugging Face özetleme sırasında hata: {exc}")
        return None


# ──────────────────────────────────────────────────────────────────────────────
# Kural Tabanlı Çıkarımsal Özetleme (Fallback)
# ──────────────────────────────────────────────────────────────────────────────

def _postprocess_summary(text: str) -> str:
    """
    Seçilmiş cümleleri son işlemden geçirir:
    - Baştaki numara/madde işaretleri temizlenir
    - Fazla boşluk giderilir
    - İlk harf büyük yapılır, cümle nokta ile bitirilir
    """
    if not text:
        return ""
    # Baştaki "5." veya "5.1." tarzı numaraları kaldır
    text = re.sub(r"^\d+(\.\d+)*\.\s*", "", text)
    # Tire veya madde işaretiyle başlayan satırları temizle
    text = re.sub(r"^[•·\-–—]\s*", "", text)
    # Fazla boşluk
    text = re.sub(r" {2,}", " ", text).strip()
    # İlk harf büyük
    if len(text) > 1:
        text = text[0].upper() + text[1:]
    # Cümle sonu noktalama
    if text and text[-1] not in ".!?":
        text += "."
    return text


def _rule_based_summarize(text: str, max_sentences: int = 3) -> str:
    """
    İyileştirilmiş kural tabanlı çıkarımsal özetleme.
    Cümle kalitesini filtreler, soyutlayıcı özetlemeye yakın çıktı üretir.
    """
    if not text:
        return ""

    raw_sentences = re.split(r"(?<=[.!?])\s+", text)

    # Ön filtreleme
    sentences: list[str] = []
    for s in raw_sentences:
        s = s.strip()
        # Baştaki madde numaralarını kaldır (5., 5.1.)
        s = re.sub(r"^\d+(\.\d+)*\.\s*", "", s).strip()
        # Çok kısa veya boş cümleleri atla
        if len(s) < 35:
            continue
        # Tamamen büyük harf → başlık → atla
        if s.isupper():
            continue
        # Bölüm-başlığı kalıpları (X ne için kullanılır / nasıl kullanılır)
        if re.match(
            r"^\w{1,40}\s+(nedir|ne\s+için|nasıl\s+kullan|kullanmadan\s+önce|saklama|muhafaza|ambalaj)",
            s,
            re.IGNORECASE,
        ):
            continue
        # "X'in saklanması Başlıkları yer almaktadır" kalıbını atla
        if re.search(r"başlıklar[ıi]\s+yer\s+almaktadır", s, re.IGNORECASE):
            continue
        sentences.append(s)

    if not sentences:
        # Hiç uygun cümle yoksa temizlenmiş ham metni kırp
        return _postprocess_summary(re.sub(r"\d+(\.\d+)?\.\s*", "", text[:400]))

    # Anahtar kelime puanlaması
    keyword_weights: dict[str, float] = {
        r"kullan[ıi]l[ıi]r": 2.0,
        r"öneril[ei]r": 1.8,
        r"dikkat": 1.5,
        r"günde\s+\d+": 2.5,
        r"\d+\s*(mg|ml|tablet|kapsül|damla)": 2.2,
        r"yan\s+etki": 1.8,
        r"kullanmay[ıi]n": 2.0,
        r"doktoru[na]": 1.5,
        r"tedavi": 1.5,
        r"sabah|akşam|öğlen|gece": 1.8,
        r"tok\s*karna|aç\s*karna": 1.8,
        r"belirt": 1.2,
        r"etkin\s+madde|etkisi": 1.3,
    }

    scored: list[tuple[float, int, str]] = []
    for idx, sentence in enumerate(sentences):
        score = 0.0
        for pattern, weight in keyword_weights.items():
            if re.search(pattern, sentence, re.IGNORECASE):
                score += weight
        # Pozisyon avantajı: öndeki cümleler daha önemli
        position_bonus = 1.0 / (idx + 1) * 0.5
        scored.append((score + position_bonus, idx, sentence))

    # Puana göre en iyi cümleleri seç, orijinal sıraya göre yeniden diz
    top = sorted(scored, reverse=True)[:max_sentences]
    top_ordered = sorted(top, key=lambda x: x[1])

    # Cümleleri birleştir: her biri nokta ile bitmeli
    parts = []
    for _, _, s in top_ordered:
        s = s.strip()
        if s and s[-1] not in ".!?":
            s += "."
        parts.append(s)

    return _postprocess_summary(" ".join(parts))


# ──────────────────────────────────────────────────────────────────────────────
# Bölüm Düzeyi Özetleme
# ──────────────────────────────────────────────────────────────────────────────

def _summarize_section(raw_text: str, use_hf: bool = True) -> str:
    """
    Tek bir bölümü özetler.
    Önce Hugging Face dener; başarısız olursa kural tabanlıya düşer.
    Her iki yöntemde de çıktı _postprocess_summary ile temizlenir.
    """
    if not raw_text:
        return ""

    # Stil transferi: jargon → günlük dil
    plain = _plain_language(raw_text)

    # HF özetleme (opsiyonel)
    if use_hf:
        hf_result = _hf_summarize(plain, max_length=120, min_length=25)
        if hf_result:
            return _postprocess_summary(hf_result.strip())

    # Fallback: kural tabanlı
    return _rule_based_summarize(plain, max_sentences=3)


# ──────────────────────────────────────────────────────────────────────────────
# Yapılandırılmış 3-Kategori Özet Oluşturucular
# ──────────────────────────────────────────────────────────────────────────────

# Cümle sınıflandırma kalıpları
_INDICATION_SENTENCE_RE = re.compile(
    r"(?:tedavisinde\s+kullan|için\s+kullan[ıi]l[ıi]r|tedavi\s+ed[ei]r|"
    r"kullanılmaktad[ıi]r|grubuna\s+ait|etki\s+göster|endikasy)",
    re.IGNORECASE,
)

_DOSAGE_SENTENCE_RE = re.compile(
    r"(?:günde|sabah|akşam|öğlen|gece|kez\b|defa\b|"
    r"tok\s*karna|aç\s*karna|\d+\s*(?:mg|ml|tablet|kapsül|damla)|"
    r"uygulan[a-z]*|sürülür|alın[ıi]z|içilir|tedavi\s+süresi|hafta)",
    re.IGNORECASE,
)

_WARNING_SENTENCE_RE = re.compile(
    r"(?:kullanmay[ıi]n[ıi]z?|kullanılmaz\b|dikkat|bildiriniz|durdurunuz|"
    r"doktoru[na]\b|yan\s+etki\b|aler[jg][iı]|alerjik|kontrendike|"
    r"hamileyseniz|emziriyorsan[ıi]z|çocuklarda)",
    re.IGNORECASE,
)


def _clean_sentence(s: str) -> str:
    """Tek bir cümleyi temizler ve standart hale getirir."""
    s = re.sub(r"^\d+(\.\d+)*\.\s*", "", s).strip()
    s = re.sub(r"^[•·\-–—]\s*", "", s).strip()
    s = re.sub(r"\s+", " ", s)
    if len(s) > 1:
        s = s[0].upper() + s[1:]
    if s and s[-1] not in ".!?":
        s += "."
    return s


def _sentences_list(text: str) -> list[str]:
    """Metni filtrelenmiş cümle listesine dönüştürür."""
    raw = re.split(r"(?<=[.!?])\s+", text)
    result: list[str] = []
    for s in raw:
        s = re.sub(r"^\d+(\.\d+)*\.\s*", "", s.strip()).strip()
        if len(s) < 30 or s.isupper():
            continue
        if re.search(r"başlıklar[ıi]\s+yer\s+almaktadır", s, re.IGNORECASE):
            continue
        result.append(s)
    return result


def _build_temel_faydasi(sections: dict[str, str], clean_full: str) -> list[str]:
    """🌟 İlacın ne için kullanıldığını sade, anlaşılır cümlelerle listeler."""
    source = _plain_language(sections.get("indication") or "")
    if len(source.split()) < 20:
        source = source + " " + " ".join(clean_full.split()[:300])

    sentences = _sentences_list(source)
    bullets: list[str] = []
    seen: set[str] = set()

    for s in sentences:
        if re.search(
            r"(cam\s+şişe|renksiz\s+saydam|saydam\s+sıvı|ambalaj\b|ml['\s]lik)",
            s, re.IGNORECASE,
        ):
            continue
        if re.search(_INDICATION_SENTENCE_RE, s):
            sc = _clean_sentence(_plain_language(s))
            key = sc[:50].lower()
            if key not in seen:
                seen.add(key)
                bullets.append(sc)
        if len(bullets) >= 2:
            break

    if not bullets:
        for s in sentences[:5]:
            if re.search(r"(cam\s+şişe|renksiz|saydam\s+sıvı)", s, re.IGNORECASE):
                continue
            sc = _clean_sentence(_plain_language(s))
            if len(sc) > 40:
                bullets.append(sc)
                break

    return bullets or ["Kullanım amacı bilgisi bulunamadı."]


def _build_kullanim_sekli(
    sections: dict[str, str], dosage_entities: list[str]
) -> list[str]:
    """🥄 Doz ve uygulama talimatlarını sade maddeler halinde oluşturur."""
    source = _plain_language(sections.get("dosage") or "")
    sentences = _sentences_list(source)

    bullets: list[str] = []
    seen: set[str] = set()

    for s in sentences:
        if re.search(_DOSAGE_SENTENCE_RE, s):
            sc = _clean_sentence(s)
            key = sc[:50].lower()
            if key not in seen:
                seen.add(key)
                bullets.append(sc)
        if len(bullets) >= 3:
            break

    if not bullets and dosage_entities:
        amounts = ", ".join(dosage_entities[:3])
        bullets.append(f"Tespit edilen doz bilgileri: {amounts}.")

    if not bullets:
        bullets.append("Kullanım dozunuz için doktorunuza veya eczacınıza danışın.")

    return bullets


def _build_dikkat_edilecekler(
    sections: dict[str, str], critical_side_effects: list[str]
) -> list[str]:
    """⚠️ Uyarı ve yan etkileri sade, öncelikli maddeler halinde listeler."""
    source = _plain_language(
        (sections.get("warnings") or "") + " " + (sections.get("side_effects") or "")
    ).strip()
    sentences = _sentences_list(source)

    bullets: list[str] = []
    seen: set[str] = set()

    for s in sentences:
        if re.search(_WARNING_SENTENCE_RE, s):
            sc = _clean_sentence(s)
            key = sc[:50].lower()
            if key not in seen:
                seen.add(key)
                bullets.append(sc)
        if len(bullets) >= 3:
            break

    # Kritik yan etkileri ekle (varsa)
    if critical_side_effects and len(bullets) < 4:
        eff = ", ".join(critical_side_effects[:2])
        crit = f"Ciddi belirtiler ({eff}) görülürse derhal doktora başvurun."
        if crit[:50].lower() not in {b[:50].lower() for b in bullets}:
            bullets.append(crit)

    # Her zaman güvenlik uyarısı bulansın
    if not any("doktor" in b.lower() for b in bullets):
        bullets.append(
            "Herhangi bir yan etki fark ederseniz kullanmayı bırakın ve "
            "doktorunuza danışın."
        )

    return bullets[:4]


# ──────────────────────────────────────────────────────────────────────────────
# LLM Tabanlı Özetleme (İsteğe Bağlı — OPENAI_API_KEY gerektirir)
# ──────────────────────────────────────────────────────────────────────────────

_LLM_SYSTEM_PROMPT = (
    "Sen deneyimli bir eczacısın. Verilen ilaç prospektüsünü herhangi bir kişinin "
    "(10 yaşındaki bir çocuk da dahil) rahatlıkla anlayabileceği basit, sade ve "
    "akıcı Türkçesiyle özetle.\n\n"
    "Çıktını YALNIZCA aşağıdaki JSON formatında ver, başka hiçbir şey yazma:\n"
    '{"temel_faydasi":["..."],"kullanim_sekli":["..."],'
    '"dikkat_edilecekler":["..."]}\n\n'
    "Kurallar:\n"
    "- Her liste en fazla 3 madde içermeli\n"
    "- Tıbbi terimleri sade Türkçeye çevir "
    "(örn: endikasyon→ne için kullanılır, kontrendikasyon→kullanılmaması gereken durumlar)\n"
    "- Kısa ve akıcı cümleler (maks. 20 kelime)\n"
    "- Saklama koşulları ve ruhsat bilgilerini dahil etme\n"
    "- Her cümle büyük harfle başlasın ve nokta ile bitsin"
)


def _llm_summarize(text: str, product_name: str) -> Optional[dict]:
    """
    Groq API (ücretsiz) ile yapılandırılmış 3-kategori özet üretir.
    GROQ_API_KEY yoksa veya hata olursa None döner (fallback devreye girer).
    """
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        logger.debug("GROQ_API_KEY tanımlanmamış — LLM fallback atlanıyor")
        return None

    try:
        from openai import OpenAI
    except ImportError:
        logger.info("openai paketi kurulu değil — LLM özetleme atlanıyor.")
        return None

    # Maks ~2500 kelime gönder (~3000 token)
    words = text.split()
    if len(words) > 2500:
        text = " ".join(words[:2500])

    try:
        client = OpenAI(
            api_key=api_key,
            base_url="https://api.groq.com/openai/v1",
            timeout=25.0,
        )
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": _LLM_SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": f"İlaç adı: {product_name}\n\nProspektüs:\n{text}",
                },
            ],
            max_tokens=500,
            temperature=0.3,
            response_format={"type": "json_object"},
        )
        raw = response.choices[0].message.content or "{}"
        data = json.loads(raw)
        
        # ✅ Başarı logu
        logger.info(f"✅ Groq LLM özet üretildi: {product_name}")
        
        return {
            "temel_faydasi": [str(x).strip() for x in data.get("temel_faydasi", [])[:3] if x],
            "kullanim_sekli": [str(x).strip() for x in data.get("kullanim_sekli", [])[:3] if x],
            "dikkat_edilecekler": [
                str(x).strip() for x in data.get("dikkat_edilecekler", [])[:4] if x
            ],
        }
    except json.JSONDecodeError as exc:
        logger.warning(f"Groq JSON parse hatası ({product_name}): {exc}")
        return None
    except Exception as exc:
        logger.warning(f"⚠️ Groq LLM özetleme hatası ({product_name}): {exc}")
        # FALLBACK: Kural tabanlıya düş — hiçbir şey dönme, None ile fallback devreye gir
        return None


# ──────────────────────────────────────────────────────────────────────────────
# Sonuç Önbelleği (In-Memory LRU benzeri)
# ──────────────────────────────────────────────────────────────────────────────

_CACHE_MAX = 200
_summary_cache: dict[str, MedicationSummary] = {}


def _cache_key(text: str) -> str:
    return hashlib.md5(text.encode("utf-8"), usedforsecurity=False).hexdigest()


# ──────────────────────────────────────────────────────────────────────────────
# Ana Özetleme Fonksiyonu
# ──────────────────────────────────────────────────────────────────────────────

def summarize_medication(
    product_name: str,
    description: str,
    active_ingredient: Optional[str] = None,
    atc_code: Optional[str] = None,
    category: Optional[str] = None,
    use_transformers: bool = True,
) -> MedicationSummary:
    """
    Ham prospektüs metnini kullanıcı dostu özetlere dönüştürür.

    Rapor 4.3.5'teki adımlar:
      1. Metin temizleme
      2. Semantik bölütleme (Endikasyon / Yan Etkiler / Dozaj / Uyarılar)
      3. NLP: soyutlayıcı özetleme (HF) veya çıkarımsal (kural tabanlı)
      4. NER: dozaj miktarları + kritik yan etkiler
      5. Güvenlik sorumluluk reddi eklenir

    Args:
        product_name:     İlaç ticari adı
        description:      Ham prospektüs metni
        active_ingredient: Etkin madde
        atc_code:         ATC kodu
        category:         Terapötik kategori
        use_transformers: HF modelini dene (True) / sadece kural tabanlı (False)

    Returns:
        MedicationSummary: Yapılandırılmış özet
    """
    # ── Önbellekten kontrol
    key = _cache_key(f"{product_name}:{description}")
    if key in _summary_cache:
        logger.debug(f"Önbellekten servis: {product_name}")
        return _summary_cache[key]

    # ── Eksik İçerik Kontrolü ─────────────────────────────────────────────────
    # description 'İkinci siteye ait içerik bulunamadı.' ifadesini içeriyorsa
    # ham metni işlemeye gerek yoktur; kullanıcıya doğrudan profesyonel
    # yönlendirme mesajı döndürülür.
    if _MISSING_CONTENT_MARKER in (description or ""):
        logger.info(f"Eksik prospektüs içeriği tespit edildi: {product_name}")
        _missing_result = MedicationSummary(
            product_name=product_name,
            active_ingredient=active_ingredient,
            atc_code=atc_code,
            category=category,
            indication="Bilgi mevcut değil.",
            side_effects="Bilgi mevcut değil.",
            dosage="Bilgi mevcut değil.",
            warnings="Bilgi mevcut değil.",
            dosage_entities=[],
            critical_side_effects=[],
            summary_method="rule_based",
            disclaimer=DISCLAIMER_SHORT,
            temel_faydasi=[_PROSPECTUS_UNAVAILABLE],
            kullanim_sekli=[_PROSPECTUS_UNAVAILABLE],
            dikkat_edilecekler=[
                "Herhangi bir yan etki fark ederseniz kullanmayı bırakın ve "
                "doktorunuza danışın."
            ],
        )
        if len(_summary_cache) >= _CACHE_MAX:
            del _summary_cache[next(iter(_summary_cache))]
        _summary_cache[key] = _missing_result
        return _missing_result

    # ── 1. Metin Temizleme
    clean = _clean_text(description or "")

    # ── 2. Semantik Bölütleme
    sections = _extract_sections(clean)

    # Eğer bölüm çıkarımı yetersizse ham metni tüm bölümler için paylaştır
    if not any(sections.values()):
        logger.debug(f"Bölüm başlıkları algılanamadı: {product_name} — ham bölüşüm yapılıyor.")
        words = clean.split()
        chunk = len(words) // 4 or 100
        sections["indication"] = " ".join(words[:chunk])
        sections["warnings"] = " ".join(words[chunk : chunk * 2])
        sections["dosage"] = " ".join(words[chunk * 2 : chunk * 3])
        sections["side_effects"] = " ".join(words[chunk * 3 :])

    # ── 3. NLP Özetleme (bölüm bazında)
    summary_method = "rule_based"
    if use_transformers and _get_summarizer() is not None:
        summary_method = "transformers"

    indication_summary = _summarize_section(sections["indication"], use_hf=use_transformers)
    side_effects_summary = _summarize_section(sections["side_effects"], use_hf=use_transformers)
    dosage_summary = _summarize_section(sections["dosage"], use_hf=use_transformers)
    warnings_summary = _summarize_section(sections["warnings"], use_hf=use_transformers)

    # ── 4. NER
    all_text = " ".join(sections.values())
    dosage_entities = _extract_dosage_entities(sections["dosage"] or all_text)
    critical_side_effects = _extract_critical_side_effects(
        sections["side_effects"] or all_text
    )

    # ── 4b. Yapılandırılmış 3-Kategori Özet
    llm_result = _llm_summarize(clean, product_name)
    if llm_result:
        temel_faydasi = llm_result["temel_faydasi"]
        kullanim_sekli = llm_result["kullanim_sekli"]
        dikkat_edilecekler = llm_result["dikkat_edilecekler"]
        summary_method = "llm"
    else:
        temel_faydasi = _build_temel_faydasi(sections, clean)
        kullanim_sekli = _build_kullanim_sekli(sections, dosage_entities)
        dikkat_edilecekler = _build_dikkat_edilecekler(sections, critical_side_effects)

    # ── 5. Özet Nesnesi Oluştur
    result = MedicationSummary(
        product_name=product_name,
        active_ingredient=active_ingredient,
        atc_code=atc_code,
        category=category,
        indication=indication_summary or "Bilgi mevcut değil.",
        side_effects=side_effects_summary or "Bilgi mevcut değil.",
        dosage=dosage_summary or "Bilgi mevcut değil.",
        warnings=warnings_summary or "Bilgi mevcut değil.",
        dosage_entities=dosage_entities,
        critical_side_effects=critical_side_effects,
        summary_method=summary_method,
        disclaimer=DISCLAIMER_SHORT,
        temel_faydasi=temel_faydasi,
        kullanim_sekli=kullanim_sekli,
        dikkat_edilecekler=dikkat_edilecekler,
    )

    # ── Önbelleğe al
    if len(_summary_cache) >= _CACHE_MAX:
        oldest_key = next(iter(_summary_cache))
        del _summary_cache[oldest_key]
    _summary_cache[key] = result

    return result


# ──────────────────────────────────────────────────────────────────────────────
# SummarizationService Sınıfı (wrapper)
# ──────────────────────────────────────────────────────────────────────────────

class SummarizationService:
    """
    İlaç prospektüsü özetleme servisi.
    summarize_medication fonksiyonunu wrapper olarak kullanır.
    """

    def __init__(self):
        """Servis başlatılır"""
        logger.info("✅ SummarizationService başlatıldı")

    def summarize(
        self,
        product_name: str,
        description: str,
        active_ingredient: Optional[str] = None,
        atc_code: Optional[str] = None,
        category: Optional[str] = None,
        use_transformers: bool = True,
    ) -> MedicationSummary:
        """
        İlaç prospektüsünü özetle.

        Args:
            product_name: İlaç adı
            description: Ham prospektüs metni
            active_ingredient: Etkin madde
            atc_code: ATC kodu
            category: Kategori
            use_transformers: Hugging Face modeli kullan

        Returns:
            MedicationSummary: Özetlenmiş bilgi
        """
        return summarize_medication(
            product_name=product_name,
            description=description,
            active_ingredient=active_ingredient,
            atc_code=atc_code,
            category=category,
            use_transformers=use_transformers,
        )
