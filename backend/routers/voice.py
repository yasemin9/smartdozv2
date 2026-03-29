"""
SmartDoz - Modül 6: Sesli Asistan Backend Router

POST /ai/voice-query
    — Kullanıcının sesli komut transkriptini alır, Groq Llama 3.1 ile
      kişiselleştirilmiş (bugünkü ilaç + doz bağlamıyla) yanıt üretir.
    — GROQ_API_KEY yoksa veya Groq ulaşılamaz ise {"answer": null,
      "source": "fallback"} döner → Flutter CommandParser devreye girer.

Güvenlik:
    • JWT zorunlu — API anahtarı asla istemciye iletilmez.
    • Kullanıcıya ait doz/ilaç verisi context olarak enjekte edilir;
      başka kullanıcının verisi hiçbir zaman dahil edilmez.
"""
from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from core.config import settings
from database import get_db
from models import DoseLog, GlobalMedication, Medication, User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Modül 6 — Sesli Asistan"])

# ── Groq / OpenAI istemcisi (lazy import) ────────────────────────────────────
_GROQ_MODEL = "llama-3.3-70b-versatile"
_GROQ_BASE   = "https://api.groq.com/openai/v1"

# ── Sistem Prompt ─────────────────────────────────────────────────────────────
_SYSTEM_PROMPT = """# ROL
Sen SmartDoz akıllı ilaç asistanısın. İlaç yönetimi, hatırlatıcılar ve genel tıbbi/farmakolojik bilgi konularında yardımcı olursun.

# TEMEL KURALLAR
- Kısa, net, sesle okunacak cevaplar ver — maksimum 3 cümle.
- Türkçe konuş, samimi ve doğal bir dil kullan.
- Kim olduğunu veya ne yapabileceğini ASLA tekrar etme.
- Tıbbi tanı veya kişiye özel tedavi önerisi verme; genel bilgi verebilirsin.

# BİLGİ KAYNAĞI SEÇİMİ (ÖNEMLİ)
İki tür soru var — hangisine girdiğine göre farklı kaynaktan yanıt ver:

1. KİŞİSEL SORULAR (kullanıcının kendi ilacı / dozu / geçmişi):
   "ilacımı aldım mı?", "bugünkü dozlarım ne?", "ilaçlarım ne zaman?"
   → YALNIZCA aşağıdaki kişisel bağlamı kullan. Bağlamda yazmıyorsa "Kayıtlarınızda bu bilgi yok." de.

2. GENEL BİLGİ SORULARI (bir ilacın ne işe yaradığı, yan etkiler, etkileşimler, nasıl kullanılır vb.):
   "aspirin ne işe yarar?", "metformin yan etkileri neler?", "bu ilaç aç karnına mı alınır?"
   → Eğitim bilgilerini kullan, doğru ve özlü Türkçe açıkla.
   → Yanıtın sonuna "Kesin bilgi için doktorunuza veya eczacınıza danışın." ekle.
   → Kişisel bağlamdaki ilaca soru soruluyorsa, bağlamdaki bilgiyi (etken madde, kategori) de dikkate al.

# DİYALOG DURUMU YÖNETİMİ (ÇOK ÖNEMLİ)
Konuşma geçmişini dikkate alarak yanıt ver. Eğer önceki mesajında bir onay sorusu sorduysan
ve kullanıcı "evet", "tamam" veya "onay" gibi bir onay veriyorsa:
- İLAÇ EKLEME onaylandıysa: 'Harika! [İlaç adı] ekliyorum.' de. action=add_medication döndür.
- İLAÇ SİLME onaylandıysa: '[İlaç adı] siliyorum.' de. action=delete_medication döndür.
- DOZ KAYDI onaylandıysa: '[İlaç adı] aldığınızı kaydediyorum.' de. action=log_dose döndür.

# ONAY SORMA KURALLARI
- Kullanıcı ilaç EKLEMEK istiyorsa: "[İlaç adı] eklemek istediğinizi onaylıyor musunuz?" de. BAŞKA ŞEY EKLEME.
- Kullanıcı ilaç SİLMEK istiyorsa: "[İlaç adı] silmek istediğinizden emin misiniz?" de.
- Kullanıcı ilaç ALDIĞINI söylüyorsa: "[İlaç adı] aldığınızı kaydedeyim mi?" de.

# KESİNLİKLE YASAK
- Onay geldikten sonra tekrar aynı onay sorusunu SORMA.
- Kullanıcının daha önce belirttiği ilacı unutma — geçmiş konuşmayı kullan.

Kullanıcının kişisel ilaç ve doz bağlamı aşağıda verilmiştir.
"""

# ── Şemalar ───────────────────────────────────────────────────────────────────

class ConversationMessage(BaseModel):
    role: str   # "user" | "assistant"
    content: str

class VoiceQueryRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=500, description="Sesli komutun transkripti")
    conversation_history: list[ConversationMessage] = Field(
        default_factory=list,
        max_length=10,
        description="Son 5 konuşma turu (kullanıcı + asistan), bağlam için",
    )

class VoiceQueryResponse(BaseModel):
    answer: Optional[str] = None
    source: str  # "groq" | "fallback"
    action: Optional[str] = None          # "delete_medication" | "add_medication" | "log_dose" | None
    medication_name: Optional[str] = None
    medication_id: Optional[int] = None
    dose_log_id: Optional[int] = None     # log_dose action için

# ── Yardımcı: Bağlam Oluşturma ────────────────────────────────────────────────

async def _build_context(user: User, db: AsyncSession) -> str:
    """Kullanıcının bugünkü ilaç + doz verilerini metin bağlamına dönüştürür."""
    today = date.today()
    today_start = datetime.combine(today, datetime.min.time())
    today_end   = datetime.combine(today, datetime.max.time())

    # İlaçlar
    med_result = await db.execute(
        select(Medication).where(Medication.user_id == user.id)
    )
    medications = med_result.scalars().all()

    # Bugünkü doz logları
    log_result = await db.execute(
        select(DoseLog).where(
            DoseLog.medication_id.in_([m.id for m in medications]),
            DoseLog.scheduled_time >= today_start,
            DoseLog.scheduled_time <= today_end,
        )
    )
    logs = log_result.scalars().all()

    # Global ilaç bilgileri (gerçek açıklama + etken madde)
    global_info: dict[str, GlobalMedication] = {}
    if medications:
        from sqlalchemy import func as _func
        for med in medications:
            # İlaç adını normalize ederek global katalogda ara (büyük/küçük harf free)
            g_result = await db.execute(
                select(GlobalMedication).where(
                    _func.lower(GlobalMedication.product_name) == med.name.lower()
                ).limit(1)
            )
            g = g_result.scalars().first()
            if g:
                global_info[med.name.lower()] = g

    if not medications:
        return "Kullanıcının kayıtlı ilacı yok."

    lines: list[str] = [
        f"Bugünün tarihi: {today.strftime('%d %B %Y')}",
        f"Kullanıcı adı: {user.first_name}",
        "",
        "Kayıtlı ilaçlar (ID | Ad | Bilgi):",
    ]
    for med in medications:
        g = global_info.get(med.name.lower())
        if g:
            active = g.active_ingredient or "—"
            desc   = g.description or ""
            cat    = " / ".join(filter(None, [g.category_1, g.category_2, g.category_3]))
            info   = f"Etken madde: {active}"
            if cat:
                info += f" | Kategori: {cat}"
            if desc:
                info += f" | Açıklama: {desc[:200]}"
        else:
            info = "global katalogda bulunamadı — bu ilaç hakkında bilgi yok"
        lines.append(f"  - ID:{med.id} | {med.name} ({med.dosage_form}), {med.usage_frequency}, son kullanma: {med.expiry_date} | {info}")

    if logs:
        lines.append("")
        lines.append("Bugünkü doz planı:")
        for log in sorted(logs, key=lambda l: l.scheduled_time):
            saat = log.scheduled_time.strftime("%H:%M")
            lines.append(f"  - LogID:{log.id} | {log.scheduled_time.strftime('%H:%M')} | {_med_name_for(log.medication_id, medications)} | Durum: {log.status}")
    else:
        lines.append("")
        lines.append("Bugün için planlanmış doz logu bulunamadı.")

    return "\n".join(lines)


def _med_name_for(med_id: int, meds: list) -> str:
    for m in meds:
        if m.id == med_id:
            return m.name
    return "Bilinmeyen ilaç"

# ── Intent Tespiti ────────────────────────────────────────────────────────────

import re as _re
import unicodedata as _uc

_TR_MAP = str.maketrans("çşğüöıİĞŞÇÜÖ", "csguoiIGSCUO")

def _normalize(text: str) -> str:
    return text.translate(_TR_MAP).lower().strip()

_RE_DELETE = _re.compile(
    r'\b(sil|kaldir|cikar|cikar|listeden\s*cikar|listeden\s*sil|'
    r'siliyor\s*musun|silmek|kayittan\s*cikar)\b',
    _re.IGNORECASE | _re.UNICODE,
)
_RE_ADD = _re.compile(
    r'\b(ekle|kaydet|sisteme\s*ekle|ilaclara\s*ekle|yeni\s*ilac)\b',
    _re.IGNORECASE | _re.UNICODE,
)
_RE_LOG_TAKEN = _re.compile(
    r'\b(aldim|ictim|kullandim|yuttum|doz[u]?\s*aldim|ilac[i]?\s*aldim|ictim)\b',
    _re.IGNORECASE | _re.UNICODE,
)


_RE_CONFIRM = _re.compile(
    r'\b(evet|tamam|onayla|onay|ok|kabul|evet\s*sil|kesinlikle|tabii)\b',
    _re.IGNORECASE | _re.UNICODE,
)
_RE_DENY = _re.compile(
    r'\b(hayir|hayır|iptal|vazgec|vazgeç|dur|istemiyorum|hayır\s*istemiyorum)\b',
    _re.IGNORECASE | _re.UNICODE,
)

# Asistan onay sorusundan action tipini çıkarmak için örüntüler
_RE_HIST_ADD    = _re.compile(r'eklemek\s*istedi\u011finizi\s*onayliyor\s*musunuz|ekleyeyim\s*mi', _re.IGNORECASE)
_RE_HIST_DELETE = _re.compile(r'silmek\s*istedi\u011finizden\s*emin\s*misiniz|silmek\s*istedi\u011finizi', _re.IGNORECASE)
_RE_HIST_LOG    = _re.compile(r'aldigini[z]?\s*kaydedeyim\s*mi|aldiginizi\s*kaydedeyim\s*mi|aldi\u011f\u0131n\u0131z\u0131\s*kaydedeyim\s*mi', _re.IGNORECASE)
# İlaç adını onay sorusundan çıkar ("Xanax eklemek istediğinizi...")
_RE_HIST_MED_NAME = _re.compile(
    r'^(.+?)\s+(?:eklemek|silmek|aldi\u011f\u0131n\u0131z)',
    _re.IGNORECASE | _re.UNICODE
)


def _extract_action_from_history(
    history: list,
    medications: list,
) -> tuple[Optional[str], Optional[str], Optional[int], Optional[int]]:
    """
    Son asistan mesajındaki onay sorusundan action + ilaç bilgisini çıkarır.
    Kullanıcı 'evet' dediğinde neye onay verdiğini tarihten belirler.
    """
    # Son asistan mesajını bul (geriden)
    last_assistant = None
    for msg in reversed(history):
        role = msg.role if hasattr(msg, 'role') else msg.get('role', '')
        if role == 'assistant':
            last_assistant = msg.content if hasattr(msg, 'content') else msg.get('content', '')
            break

    if not last_assistant:
        return None, None, None, None

    norm_hist = _normalize(last_assistant)

    if _RE_HIST_DELETE.search(last_assistant):
        action = 'delete_medication'
    elif _RE_HIST_ADD.search(last_assistant):
        action = 'add_medication'
    elif _RE_HIST_LOG.search(norm_hist):
        action = 'log_dose'
    else:
        return None, None, None, None

    # İlaç adını asistan mesajından çıkar (ilk büyük harf kümesi)
    name_match = _RE_HIST_MED_NAME.search(last_assistant)
    raw_name = name_match.group(1).strip() if name_match else None
    matched = _match_medication(_normalize(raw_name), medications) if raw_name else None
    if matched:
        return action, matched.name, matched.id, None
    # Kayıtlı ilaçta eşleşme olmasa bile action'ı dön (name=raw_name ile)
    return action, raw_name, None, None


def _detect_intent(
    query: str,
    medications: list,
    dose_logs: list | None = None,
    history: list | None = None,
) -> tuple[Optional[str], Optional[str], Optional[int], Optional[int]]:
    """
    Kullanıcı sorgusundan niyet ve ilaç bilgisini çıkarır.
    Geçmiş konuşma varsa onay cevapları (evet/hayır) için history'e bakar.
    Döndürür: (action, medication_name, medication_id, dose_log_id)
    """
    norm_query = _normalize(query)

    # Onay / red kelimesi + history varsa → geçmişten action'ı al
    if history and _RE_CONFIRM.search(norm_query) and not _RE_DELETE.search(norm_query) and not _RE_ADD.search(norm_query):
        hist_action, hist_name, hist_id, hist_log = _extract_action_from_history(history, medications)
        if hist_action:
            # log_dose için bugünkü pending log ID'yi bul
            if hist_action == 'log_dose' and hist_id and dose_logs:
                pending = next(
                    (dl for dl in dose_logs
                     if dl.medication_id == hist_id and dl.status in ("Bekliyor", "Planlandı")),
                    None,
                )
                hist_log = pending.id if pending else None
            return hist_action, hist_name, hist_id, hist_log

    if _RE_DELETE.search(norm_query):
        matched = _match_medication(norm_query, medications)
        if matched:
            return "delete_medication", matched.name, matched.id, None
        return "delete_medication", None, None, None

    if _RE_ADD.search(norm_query):
        matched = _match_medication(norm_query, medications)
        name = matched.name if matched else None
        mid  = matched.id   if matched else None
        return "add_medication", name, mid, None

    if _RE_LOG_TAKEN.search(norm_query):
        matched = _match_medication(norm_query, medications)
        if matched and dose_logs:
            # Bugünkü Bekliyor doz logunu bul
            pending = next(
                (
                    dl for dl in dose_logs
                    if dl.medication_id == matched.id
                    and dl.status in ("Bekliyor", "Planlandı")
                ),
                None,
            )
            log_id = pending.id if pending else None
            return "log_dose", matched.name, matched.id, log_id
        return "log_dose", None, None, None

    return None, None, None, None


def _match_medication(norm_query: str, medications: list):
    """İlaç adını normalize edilmiş sorgu içinde arar (en uzun eşleşme önce)."""
    best = None
    best_len = 0
    for med in medications:
        med_norm = _normalize(med.name)
        # Birden fazla kelimeli adlar için tüm sözcükleri kontrol et
        words = [w for w in med_norm.split() if len(w) >= 3]
        match_count = sum(1 for w in words if w in norm_query)
        if match_count > 0 and len(med_norm) > best_len:
            best = med
            best_len = len(med_norm)
    return best



@router.post(
    "/voice-query",
    response_model=VoiceQueryResponse,
    summary="Sesli asistan sorgusu (Groq Llama 3.1)",
)
async def voice_query(
    body: VoiceQueryRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VoiceQueryResponse:
    """
    Sesli komut transkriptini Groq Llama 3.1 ile işler.
    Kullanıcının bugünkü ilaç/doz bağlamını sistem prompt'una enjekte eder.
    GROQ_API_KEY yoksa veya Groq ulaşılamaz ise `source: "fallback"` döner.
    """
    api_key = settings.GROQ_API_KEY
    if not api_key:
        logger.debug("GROQ_API_KEY tanımlı değil — fallback döndürülüyor.")
        return VoiceQueryResponse(answer=None, source="fallback")

    try:
        from openai import OpenAI  # type: ignore  # Groq, openai SDK ile uyumludur
    except ImportError:
        logger.warning("openai paketi yüklü değil — fallback döndürülüyor.")
        return VoiceQueryResponse(answer=None, source="fallback")

    # İlaçları intent tespiti için yükle
    med_result = await db.execute(
        select(Medication).where(Medication.user_id == current_user.id)
    )
    medications = med_result.scalars().all()

    # Bugünkü doz loglarını intent tespiti için yükle
    from datetime import date as _date, datetime as _datetime
    _today = _date.today()
    _today_start = _datetime.combine(_today, _datetime.min.time())
    _today_end   = _datetime.combine(_today, _datetime.max.time())
    log_result = await db.execute(
        select(DoseLog).where(
            DoseLog.medication_id.in_([m.id for m in medications]),
            DoseLog.scheduled_time >= _today_start,
            DoseLog.scheduled_time <= _today_end,
        )
    )
    today_logs = log_result.scalars().all()

    # Bağlamı oluştur (veritabanı hatası tüm isteği çökertmesin)
    try:
        context = await _build_context(current_user, db)
    except Exception as exc:
        logger.warning(f"Bağlam oluşturma hatası: {exc}")
        context = "Kullanıcı bağlamı alınamadı."

    # Intent tespiti — Groq'tan bağımsız, deterministic
    # Geçmiş konuşmayı da ver; onay cevaplarında (evet/hayır) history'den action çıkarılır
    action, med_name, med_id, dose_log_id = _detect_intent(
        body.query, list(medications), list(today_logs),
        history=body.conversation_history,
    )

    system_with_ctx = f"{_SYSTEM_PROMPT}\n\n=== KULLANICI BAĞLAMI ===\n{context}"

    try:
        client = OpenAI(
            api_key=api_key,
            base_url=_GROQ_BASE,
            timeout=15.0,
        )

        # Geçmiş mesajları sisteme ekle (max 10 tur — 5 çift)
        history_messages = [
            {"role": msg.role, "content": msg.content}
            for msg in body.conversation_history[-10:]
            if msg.role in ("user", "assistant")
        ]

        response = client.chat.completions.create(
            model=_GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_with_ctx},
                *history_messages,
                {"role": "user",   "content": body.query},
            ],
            max_tokens=256,   # Genel bilgi sorularına yetecek kadar alan
            temperature=0.3,
        )
        answer = (response.choices[0].message.content or "").strip()
        if not answer:
            return VoiceQueryResponse(answer=None, source="fallback")

        logger.info(f"[VoiceAI] user={current_user.id} action={action} q={repr(body.query)[:60]}")
        return VoiceQueryResponse(
            answer=answer,
            source="groq",
            action=action,
            medication_name=med_name,
            medication_id=med_id,
            dose_log_id=dose_log_id,
        )

    except Exception as exc:
        logger.warning(f"[VoiceAI] Groq hatası: {exc}")
        return VoiceQueryResponse(answer=None, source="fallback")


# ── İlaç Arama Endpoint (Sesli Form Sihirbazı) ───────────────────────────────

class MedSearchResult(BaseModel):
    id: int
    product_name: str
    active_ingredient: Optional[str] = None
    category_1: Optional[str] = None
    atc_code: Optional[str] = None
    barcode: Optional[str] = None


@router.get(
    "/voice-med-search",
    response_model=list[MedSearchResult],
    summary="Sesli form için global ilaç kataloğu araması",
)
async def voice_med_search(
    query: str,
    limit: int = 5,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MedSearchResult]:
    """
    Sesli asistan ilaç ekleme sihirbazı için global katalogda arama yapar.
    En iyi 5 sonucu döner (trigram benzerlik veya ILIKE fallback).
    Her sonuç: id, ürün adı, etken madde, kategori.
    """
    if not query or len(query.strip()) < 2:
        return []

    q = query.strip()

    # pg_trgm similarity denemesi; olmadığında ILIKE fallback
    try:
        from sqlalchemy import func as _func, literal
        result = await db.execute(
            select(GlobalMedication)
            .where(GlobalMedication.product_name.ilike(f"%{q}%"))
            .order_by(
                _func.similarity(GlobalMedication.product_name, q).desc()
            )
            .limit(limit)
        )
    except Exception:
        result = await db.execute(
            select(GlobalMedication)
            .where(GlobalMedication.product_name.ilike(f"%{q}%"))
            .limit(limit)
        )

    meds = result.scalars().all()
    return [
        MedSearchResult(
            id=m.id,
            product_name=m.product_name,
            active_ingredient=m.active_ingredient,
            category_1=m.category_1,
            atc_code=m.atc_code,
            barcode=m.barcode,
        )
        for m in meds
    ]
