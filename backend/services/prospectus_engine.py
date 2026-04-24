"""
SmartDoz - Prospektüs Özeti Motoru

Veri akışı:
  DB → (bulundu) ✅ ProspectusDetail döner
  DB → (bulunamadı) → Groq API çağrı → Dinamik özet → Cache kaydet (24h)
  Groq → (hata) → 1 saat cache → retry mekanizması

Rapor 4.3.5: Müşteri API çağrısı → Backend → HF | Groq
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import text

logger = logging.getLogger(__name__)


# ── In-Memory Cache ──────────────────────────────────────────────────────────
_PROSPECTUS_CACHE: dict[str, dict] = {}


class ProspectusDetail:
    """Prospektüs özeti veri modeli"""

    def __init__(
        self,
        drug_name: str,
        active_ingredient: Optional[str],
        indication: str,
        dosage: str,
        side_effects: str,
        contraindications: str,
        storage: str,
        source: str = "database",  # "database" | "groq"
        cached_at: Optional[datetime] = None,
    ):
        self.drug_name = drug_name
        self.active_ingredient = active_ingredient
        self.indication = indication
        self.dosage = dosage
        self.side_effects = side_effects
        self.contraindications = contraindications
        self.storage = storage
        self.source = source
        self.cached_at = cached_at or datetime.now()

    def to_dict(self) -> dict:
        return {
            "drug_name": self.drug_name,
            "active_ingredient": self.active_ingredient,
            "indication": self.indication,
            "dosage": self.dosage,
            "side_effects": self.side_effects,
            "contraindications": self.contraindications,
            "storage": self.storage,
            "source": self.source,
            "cached_at": self.cached_at.isoformat(),
        }


class ProspectusEngine:
    """PostgreSQL uyumlu Prospektüs indirme ve işleme servisi"""

    def __init__(self):
        self.timeout = aiohttp.ClientTimeout(total=30)
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }

    async def get_prospectus(
        self,
        drug_name: str,
        db_session=None,
        from_models=None,
    ) -> Optional[ProspectusDetail]:
        """
        Prospektüs özetini alır.
        
        Öncelik:
        1. Memory cache
        2. Veritabanı (GlobalMedication.prospectus_summary)
        3. Groq API (dinamik)
        """
        cache_key = drug_name.lower().strip()

        # 1️⃣ Cache kontrol
        cached = self._check_cache(cache_key)
        if cached is not None:
            logger.debug(f"✅ Cache hit: {cache_key}")
            return cached

        # 2️⃣ Veritabanından çek
        if db_session and from_models:
            db_result = await self._fetch_from_db(cache_key, db_session, from_models)
            if db_result:
                self._set_cache(cache_key, db_result, hours=24)
                logger.info(f"📊 DB'den alındı: {drug_name}")
                return db_result

        # 3️⃣ Groq API ile dinamik oluştur
        if self.groq_api_key:
            api_result = await self._generate_from_groq(drug_name)
            if api_result:
                self._set_cache(cache_key, api_result, hours=24)
                logger.info(f"🤖 Groq'tan üretildi: {drug_name}")
                return api_result
            else:
                # Hata → kısa TTL ile cache et (tekrar denemesi geciktir)
                self._set_cache(cache_key, None, hours=1)

        logger.warning(f"❌ Prospektüs bulunamadı: {drug_name}")
        return None

    def _check_cache(self, key: str) -> Optional[ProspectusDetail]:
        """TTL ile cache kontrol"""
        if key not in _PROSPECTUS_CACHE:
            return None

        entry = _PROSPECTUS_CACHE[key]
        if entry.get("expires_at") and datetime.now() > entry["expires_at"]:
            del _PROSPECTUS_CACHE[key]
            return None

        return entry.get("data")

    def _set_cache(
        self,
        key: str,
        data: Optional[ProspectusDetail],
        hours: int = 24,
    ) -> None:
        """Cache'e yaz"""
        _PROSPECTUS_CACHE[key] = {
            "data": data,
            "expires_at": datetime.now() + timedelta(hours=hours),
        }

    async def _fetch_from_db(
        self,
        norm_name: str,
        db_session,
        from_models,
    ) -> Optional[ProspectusDetail]:
        """Veritabanından çek"""
        from sqlalchemy import select, func as _func

        GlobalMedication = from_models.GlobalMedication

        try:
            result = await db_session.execute(
                select(GlobalMedication)
                .where(_func.lower(GlobalMedication.product_name) == norm_name)
                .limit(1)
            )
            g_med = result.scalars().first()

            if not g_med:
                return None

            # prospectus_summary JSON veya dict olabilir
            summary = g_med.prospectus_summary or {}
            if isinstance(summary, str):
                try:
                    summary = json.loads(summary)
                except (json.JSONDecodeError, ValueError):
                    summary = {}

            return ProspectusDetail(
                drug_name=g_med.product_name,
                active_ingredient=g_med.active_ingredient or "Bilinmiyor",
                indication=summary.get("indication", ""),
                dosage=summary.get("dosage", ""),
                side_effects=summary.get("side_effects", ""),
                contraindications=summary.get("contraindications", ""),
                storage=summary.get("storage", ""),
                source="database",
            )

        except Exception as exc:
            logger.error(f"DB prospektüs hatası ({norm_name}): {exc}")
            return None

    async def _generate_from_groq(self, drug_name: str) -> Optional[ProspectusDetail]:
        """Groq ile dinamik özet oluştur"""
        try:
            from openai import OpenAI
        except ImportError:
            logger.warning("openai paketi yüklü değil")
            return None

        prompt = f"""
{drug_name} ilacı hakkında tıbbi prospektüs özeti yaz. Türkçe ve kısa olsun.

Aşağıdaki bölümleri içer (her biri maksimum 3 cümle):
1. NE İÇİN KULLANILIR: Endikasyon
2. DOZA SAHIP: Doz ve kullanım şekli
3. YAN ETKİLER: Yaygın yan etkiler
4. KÖTÜLEŞMEYECEK: Kontrendikasyonlar
5. SAKLAMA: Saklama koşulları

Yanıt formatı (boş alanları doldurmayın):
NE İÇİN KULLANILIR: ...
DOZA SAHIP: ...
YAN ETKİLER: ...
KÖTÜLEŞMEYECEK: ...
SAKLAMA: ...
"""

        try:
            client = OpenAI(
                api_key=self.groq_api_key,
                base_url="https://api.groq.com/openai/v1",
                timeout=15.0,
            )

            response = client.chat.completions.create(
                model="llama-3.1-8b-instant",
                messages=[
                    {
                        "role": "system",
                        "content": "Sen deneyimli bir eczacısın. Kısa ve açık yanıtlar ver.",
                    },
                    {"role": "user", "content": prompt},
                ],
                max_tokens=400,
                temperature=0.2,
            )

            text = (response.choices[0].message.content or "").strip()
            return self._parse_groq_response(drug_name, text)

        except Exception as exc:
            logger.error(f"Groq prospektüs hatası ({drug_name}): {exc}")
            return None

    def _parse_groq_response(self, drug_name: str, text: str) -> Optional[ProspectusDetail]:
        """Groq yanıtını parse et"""
        sections = {
            "indication": "",
            "dosage": "",
            "side_effects": "",
            "contraindications": "",
            "storage": "",
        }

        lines = text.split("\n")
        current_section = None

        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Bölüm tespiti
            if "NE İÇİN KULLANILIR" in line.upper():
                current_section = "indication"
            elif "DOZA SAHIP" in line.upper() or "DOZ" in line.upper():
                current_section = "dosage"
            elif "YAN ETKİ" in line.upper():
                current_section = "side_effects"
            elif "KÖTÜLEŞMEYECEK" in line.upper() or "KONTRENDIKASYON" in line.upper():
                current_section = "contraindications"
            elif "SAKLAMA" in line.upper():
                current_section = "storage"
            elif current_section and not line.startswith(":"):
                # İçerik satırı
                sections[current_section] += line.replace(":", "").strip() + " "

        # Boş alanlar için varsayılan
        for key in sections:
            sections[key] = sections[key].strip() or "Bilgi bulunamamıştır."

        try:
            return ProspectusDetail(
                drug_name=drug_name,
                active_ingredient="Bilinmiyor",
                indication=sections["indication"],
                dosage=sections["dosage"],
                side_effects=sections["side_effects"],
                contraindications=sections["contraindications"],
                storage=sections["storage"],
                source="groq",
            )
        except Exception as exc:
            logger.error(f"Parse hatası: {exc}")
            return None


# ── Singleton ────────────────────────────────────────────────────────────────
prospectus_engine: Optional[ProspectusEngine] = None


def init_prospectus_engine(groq_api_key: Optional[str] = None) -> ProspectusEngine:
    """Motoru başlat"""
    global prospectus_engine
    prospectus_engine = ProspectusEngine(groq_api_key=groq_api_key)
    logger.info("✅ ProspectusEngine başlatıldı")
    return prospectus_engine
