"""
SmartDoz - İlaç Yönetimi Router'ı

GET    /medications/       — Kullanıcının ilaçlarını listele
POST   /medications/       — Yeni ilaç ekle
PUT    /medications/{id}   — İlaç güncelle
DELETE /medications/{id}   — İlaç sil

Tüm endpoint'ler JWT ile korumalıdır.
"""
from datetime import date as dt_date, datetime
import re

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, or_, text
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from auth import get_current_user
from database import get_db
from models import DoseLog, GlobalMedication, Medication, User
from schemas import (
    CriticalInteractionWarningResponse,
    GlobalMedicationSearchResult,
    InteractionWarningResponse,
    MedicationCreate,
    MedicationResponse,
    MedicationScheduleDoseResponse,
    MedicationScheduleResponse,
    MedicationUpdate,
)
from services.scheduler import (
    create_future_dose_logs_for_medication,
    generate_schedule_for_medication_on_date,
)
from services.interaction_engine import interaction_engine, translate_to_turkish

router = APIRouter(prefix="/medications", tags=["İlaçlar"])


DETERMINISTIC_INTERACTION_RULES: dict[frozenset[str], dict[str, str]] = {
    frozenset(["B01AC06", "B01AC04"]): {
        "risk_level": "YUKSEK_SEVIYE",
        "title": "Ciddi Kanama Riski",
        "description": (
            "Aspirin (B01AC06) ve Plavix/Klopidogrel (B01AC04) birlikte kullanımında "
            "kanama riski klinik olarak anlamlı biçimde artabilir."
        ),
    },
}


_TR_CHAR_MAP = str.maketrans(
    "\u00e7\u015f\u011f\u00fc\u00f6\u0131\u0130\u011e\u015e\u00c7\u00dc\u00d6",
    "csguoiIGSCUO",
)


def _normalize_tr(text_val: str) -> str:
    """Türkçe karakterleri ASCII karşılıklarına dönüştürür ve küçük harfe çevirir."""
    return text_val.translate(_TR_CHAR_MAP).lower().strip()


# İlaç adından tuz/form sonuçlarını atar: "Varfarin Sodyum" → "varfarin"
_SALT_SUFFIXES = re.compile(
    r"\b(sodyum|potasyum|kalsiyum|magnezyum|hidroklorur|hidroklorurmonohidrat|"
    r"monohidrat|dihidrat|anhidr|asetat|sulfat|suleyfat|maleat|tartrat|sitrat|"
    r"sodium|potassium|calcium|hydrochloride|hcl|monohydrate|dihydrate|"
    r"acetate|sulfate|maleate|tartrate|citrate|phosphate|fosfat|bromide|bromur|"
    r"mesylate|besylate|fumarate|succinate)\b.*$",
    re.IGNORECASE,
)


def _clean_ingredient(token: str) -> str:
    """İlaç etken maddesinden tuz/form sonuçlarını temizler. "varfarin sodyum" → "varfarin"."""
    cleaned = _SALT_SUFFIXES.sub("", token).strip()
    return cleaned if len(cleaned) >= 4 else token


def _ingredient_tokens(value: str | None) -> list[str]:
    """Etken madde metnini normalize edilmiş token'lara böler (örn: 'A, B / C')."""
    if not value:
        return []
    raw = re.split(r"[,/;+]|\bve\b|\band\b", value, flags=re.IGNORECASE)
    tokens = [_normalize_tr(t) for t in raw if t and t.strip()]
    seen: set[str] = set()
    unique_tokens: list[str] = []
    for token in tokens:
        if token not in seen:
            seen.add(token)
            unique_tokens.append(token)
    return unique_tokens


def _to_turkish_warning(description: str) -> str:
    """DrugInteractions İngilizce açıklamasını Türkçe uyarı formatına çevirir."""
    d = description.strip()
    replacements = [
        # Etki artırma / azaltma kalıpları
        ("may increase the photosensitizing activities of", "fotosensitize etkilerini artırabilir:"),
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
        ("may increase the central nervous system depressant", "merkezi sinir sistemi baskılayıcı etkilerini artırabilir:"),
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
        # Genel kalıplar
        ("The risk or severity of adverse effects can be increased when", "Advers etki riski/şiddeti artabilir:"),
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
    for en, tr in replacements:
        d = d.replace(en, tr)
    if d == description.strip():
        return f"Potansiyel etkileşim: {description.strip()}"
    return d


def _name_based_atc_fallback(medication_name: str) -> str | None:
    """ATC kodu yoksa deterministik isim fallback'i uygular."""
    name = medication_name.lower().strip()
    if "plavix" in name or "clopidogrel" in name or "klopidogrel" in name:
        return "B01AC04"
    return None


async def _resolve_active_ingredient(medication: Medication, db: AsyncSession) -> str | None:
    """İlaçtan etken maddeyi çözer; yoksa global katalogdan ürün adına göre arar.
    Hiçbiri bulunamazsa ilaç adının kendisini döndürür (Warfarin gibi jenerik/İngilizce isimler)."""
    if medication.active_ingredient and medication.active_ingredient.strip():
        return medication.active_ingredient.strip()

    name = medication.name.strip()

    # 1. Tam ürün adı eşleşmesi
    lookup = await db.execute(
        select(GlobalMedication.active_ingredient)
        .where(GlobalMedication.product_name.ilike(name))
        .limit(1)
    )
    found = lookup.scalar_one_or_none()
    if found and found.strip():
        return found.strip()

    # 2. İçerik araması — "TEGRETOL ŞURUP" → "%TEGRETOL%" ile eşleşir
    first_word = name.split()[0] if name.split() else name
    if len(first_word) >= 4:
        lookup2 = await db.execute(
            select(GlobalMedication.active_ingredient)
            .where(GlobalMedication.product_name.ilike(f"%{first_word}%"))
            .limit(1)
        )
        found2 = lookup2.scalar_one_or_none()
        if found2 and found2.strip():
            return found2.strip()

    # 3. pg_trgm benzerlik araması
    sim_res = await db.execute(
        text(
            "SELECT active_ingredient FROM global_medications "
            "WHERE similarity(LOWER(product_name), LOWER(:n)) > 0.4 "
            "ORDER BY similarity(LOWER(product_name), LOWER(:n)) DESC LIMIT 1"
        ),
        {"n": name},
    )
    found3 = sim_res.scalar_one_or_none()
    if found3 and found3.strip():
        return found3.strip()

    # Son çare: ilaç adını doğrudan kullan — 'Warfarin', 'Aspirin' gibi jenerik isimler
    return name if name else None


async def _resolve_atc_code(medication: Medication, db: AsyncSession) -> str | None:
    """İlaç için ATC kodunu çözer: medication.atc_code -> global katalog -> isim fallback."""
    if medication.atc_code and medication.atc_code.strip():
        return medication.atc_code.strip().upper()

    by_exact_name = await db.execute(
        select(GlobalMedication.atc_code)
        .where(GlobalMedication.product_name.ilike(medication.name.strip()))
        .limit(1)
    )
    found = by_exact_name.scalar_one_or_none()
    if found and found.strip():
        return found.strip().upper()

    by_contains = await db.execute(
        select(GlobalMedication.atc_code)
        .where(GlobalMedication.product_name.ilike(f"%{medication.name.strip()}%"))
        .limit(1)
    )
    found_contains = by_contains.scalar_one_or_none()
    if found_contains and found_contains.strip():
        return found_contains.strip().upper()

    return _name_based_atc_fallback(medication.name)


def check_interaction(
    atc_a: str,
    atc_b: str,
    med_name_a: str,
    med_name_b: str,
) -> CriticalInteractionWarningResponse | None:
    """Algoritma 2: Deterministik ikili ilaç etkileşim kontrolü."""
    rule = DETERMINISTIC_INTERACTION_RULES.get(frozenset([atc_a, atc_b]))
    if not rule:
        return None
    return CriticalInteractionWarningResponse(
        risk_level=rule["risk_level"],
        title=rule["title"],
        message=(
            f"KRITIK UYARI: {med_name_a} ve {med_name_b} etkileşimi yüksek risk taşır!"
        ),
        medication_a=med_name_a,
        medication_b=med_name_b,
        atc_a=atc_a,
        atc_b=atc_b,
        description=rule["description"],
    )


async def _collect_critical_interaction_warnings(
    current_user: User,
    db: AsyncSession,
) -> list[CriticalInteractionWarningResponse]:
    meds_res = await db.execute(
        select(Medication)
        .where(Medication.user_id == current_user.id)
        .order_by(Medication.name)
    )
    medications = meds_res.scalars().all()
    if len(medications) < 2:
        return []

    resolved: list[tuple[Medication, str]] = []
    for med in medications:
        atc = await _resolve_atc_code(med, db)
        if atc:
            resolved.append((med, atc))

    warnings: list[CriticalInteractionWarningResponse] = []
    seen_pairs: set[tuple[str, str]] = set()
    for i in range(len(resolved)):
        med_a, atc_a = resolved[i]
        for j in range(i + 1, len(resolved)):
            med_b, atc_b = resolved[j]
            key = tuple(sorted([atc_a, atc_b]))
            if key in seen_pairs:
                continue
            seen_pairs.add(key)
            warning = check_interaction(atc_a, atc_b, med_a.name, med_b.name)
            if warning:
                warnings.append(warning)

    return warnings


async def _build_interaction_warnings(
    new_medication: Medication,
    current_user: User,
    db: AsyncSession,
) -> list[InteractionWarningResponse]:
    """Yeni ilacı kullanıcının mevcut ilaçlarıyla karşılaştırır.
    Önce InteractionEngine (pandas + rapidfuzz/Levenshtein) kullanır;
    eğer engine yüklenmemişse pg_trgm similarity'ye düşer."""
    new_ingredient = await _resolve_active_ingredient(new_medication, db)
    if not new_ingredient:
        return []
    new_clean = _clean_ingredient(_normalize_tr(new_ingredient))

    existing_res = await db.execute(
        select(Medication)
        .where(
            Medication.user_id == current_user.id,
            Medication.id != new_medication.id,
        )
        .order_by(Medication.name)
    )
    existing_medications = existing_res.scalars().all()
    if not existing_medications:
        return []

    warnings: list[InteractionWarningResponse] = []
    seen: set[str] = set()
    use_engine = interaction_engine.is_loaded

    for existing in existing_medications:
        existing_ingredient = await _resolve_active_ingredient(existing, db)
        if not existing_ingredient:
            continue
        existing_clean = _clean_ingredient(_normalize_tr(existing_ingredient))

        found_description: str | None = None

        if use_engine:
            # ── Birincil: InteractionEngine (rapidfuzz Levenshtein, Türkçe-İngilizce farkı aşar) ──
            hit = interaction_engine.lookup(new_clean, existing_clean)
            if hit:
                found_description = hit["description"]
        
        if not found_description:
            # ── Fallback: DrugInteractions tablosunda tam eşleşme ──
            new_tokens = _ingredient_tokens(new_ingredient)
            existing_tokens = _ingredient_tokens(existing_ingredient)

            for new_token in new_tokens:
                if found_description:
                    break
                new_token_clean = _clean_ingredient(new_token)
                for existing_token in existing_tokens:
                    existing_token_clean = _clean_ingredient(existing_token)

                    exact_query = await db.execute(
                        text(
                            '''
                            SELECT description
                            FROM "DrugInteractions"
                            WHERE
                                (LOWER(drug1) = :a AND LOWER(drug2) = :b)
                                OR (LOWER(drug1) = :b AND LOWER(drug2) = :a)
                            LIMIT 1
                            '''
                        ),
                        {"a": new_token_clean, "b": existing_token_clean},
                    )
                    found_description = exact_query.scalar_one_or_none()
                    if found_description:
                        break

                    # pg_trgm (düşük threshold — engine yokken son çare)
                    sim_query = await db.execute(
                        text(
                            '''
                            SELECT description
                            FROM "DrugInteractions"
                            WHERE
                                (similarity(LOWER(drug1),:a) > 0.55 AND similarity(LOWER(drug2),:b) > 0.55)
                                OR (similarity(LOWER(drug1),:b) > 0.55 AND similarity(LOWER(drug2),:a) > 0.55)
                            ORDER BY GREATEST(
                                similarity(LOWER(drug1),:a)*similarity(LOWER(drug2),:b),
                                similarity(LOWER(drug1),:b)*similarity(LOWER(drug2),:a)
                            ) DESC
                            LIMIT 1
                            '''
                        ),
                        {"a": new_token_clean, "b": existing_token_clean},
                    )
                    found_description = sim_query.scalar_one_or_none()
                    if found_description:
                        break

        if found_description:
            dedup = f"{existing.name.lower()[:30]}|{found_description[:40]}"
            if dedup in seen:
                continue
            seen.add(dedup)
            warnings.append(
                InteractionWarningResponse(
                    with_medication_name=existing.name,
                    description=translate_to_turkish(found_description),
                )
            )

    return warnings


@router.get(
    "/",
    response_model=List[MedicationResponse],
    summary="Kullanıcının ilaç listesi",
)
async def list_medications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Oturumdaki kullanıcıya ait tüm ilaçları döner."""
    result = await db.execute(
        select(Medication)
        .where(Medication.user_id == current_user.id)
        .order_by(Medication.expiry_date)
    )
    return result.scalars().all()


@router.get(
    "/interactions/critical",
    response_model=List[CriticalInteractionWarningResponse],
    summary="Algoritma 2: kritik ikili etkileşimleri getir",
)
async def list_critical_interactions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await _collect_critical_interaction_warnings(current_user, db)


@router.post(
    "/interactions/check",
    response_model=List[InteractionWarningResponse],
    summary="Yeni ilaç için etkileşim ön kontrolü (kaydetmeden)",
)
async def check_medication_interactions(
    medication_data: MedicationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """UYARIOLUSTUR akışı için yeni ilacı kaydetmeden etkileşimleri hesaplar."""
    preview_med = Medication(
        user_id=current_user.id,
        **medication_data.model_dump(),
    )
    return await _build_interaction_warnings(preview_med, current_user, db)


@router.post(
    "/",
    response_model=MedicationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Yeni ilaç ekle",
)
async def create_medication(
    medication_data: MedicationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcıya yeni ilaç ekler, etkileşim kontrolü yapar ve 30 günlük planlanan dozları hazırlar."""
    new_med = Medication(
        user_id=current_user.id,
        **medication_data.model_dump(),
    )
    db.add(new_med)
    await db.commit()
    await db.refresh(new_med)

    interaction_warnings = await _build_interaction_warnings(new_med, current_user, db)

    # Modül 2 veri senkronizasyonu: takvimin boş kalmaması için 30 gün seed edilir.
    await create_future_dose_logs_for_medication(new_med.id, db, days=30)

    return MedicationResponse(
        id=new_med.id,
        user_id=new_med.user_id,
        name=new_med.name,
        dosage_form=new_med.dosage_form,
        usage_frequency=new_med.usage_frequency,
        usage_time=new_med.usage_time,
        expiry_date=new_med.expiry_date,
        active_ingredient=new_med.active_ingredient,
        atc_code=new_med.atc_code,
        barcode=new_med.barcode,
        interaction_warnings=interaction_warnings,
    )


@router.get(
    "/schedule/{date_str}",
    response_model=MedicationScheduleResponse,
    summary="Seçilen güne ait doz planı (geçmiş/bugün/gelecek)",
)
async def get_medication_schedule_by_date(
    date_str: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Evrensel doz sorgulama:
      - Geçmiş gün: yalnızca gerçek loglar (Alındı/Atlandı/Ertelendi)
      - Bugün: DB'deki gerçek günlük loglar
      - Gelecek: Algoritma 1 ile sanal Planlandı dozları
    """
    try:
        target = dt_date.fromisoformat(date_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz tarih formatı. YYYY-MM-DD kullanın.",
        )

    meds_res = await db.execute(
        select(Medication)
        .where(Medication.user_id == current_user.id)
        .order_by(Medication.name)
    )
    medications = meds_res.scalars().all()
    if not medications:
        return MedicationScheduleResponse(date=date_str, mode="today", dose_logs=[])

    med_map = {m.id: m for m in medications}
    med_ids = list(med_map.keys())
    today = dt_date.today()

    day_start = datetime.combine(target, datetime.min.time())
    day_end = datetime.combine(target, datetime.max.time())

    if target < today:
        # Geçmiş: sadece kullanıcı aksiyonunu temsil eden gerçek loglar.
        logs_res = await db.execute(
            select(DoseLog)
            .where(
                DoseLog.medication_id.in_(med_ids),
                DoseLog.scheduled_time >= day_start,
                DoseLog.scheduled_time <= day_end,
                DoseLog.status.in_(["Alındı", "Atlandı", "Ertelendi"]),
            )
            .order_by(DoseLog.scheduled_time)
        )
        logs = logs_res.scalars().all()
        dose_logs = [
            MedicationScheduleDoseResponse(
                id=log.id,
                medication_id=log.medication_id,
                medication_name=med_map[log.medication_id].name,
                dosage_form=med_map[log.medication_id].dosage_form,
                scheduled_time=log.scheduled_time,
                actual_time=log.actual_time,
                status=log.status,
                notes=log.notes,
                is_virtual=False,
            )
            for log in logs
            if log.medication_id in med_map
        ]
        return MedicationScheduleResponse(date=date_str, mode="past", dose_logs=dose_logs)

    if target == today:
        logs_res = await db.execute(
            select(DoseLog)
            .where(
                DoseLog.medication_id.in_(med_ids),
                DoseLog.scheduled_time >= day_start,
                DoseLog.scheduled_time <= day_end,
            )
            .order_by(DoseLog.scheduled_time)
        )
        logs = logs_res.scalars().all()
        dose_logs = [
            MedicationScheduleDoseResponse(
                id=log.id,
                medication_id=log.medication_id,
                medication_name=med_map[log.medication_id].name,
                dosage_form=med_map[log.medication_id].dosage_form,
                scheduled_time=log.scheduled_time,
                actual_time=log.actual_time,
                status=log.status,
                notes=log.notes,
                is_virtual=False,
            )
            for log in logs
            if log.medication_id in med_map
        ]
        return MedicationScheduleResponse(date=date_str, mode="today", dose_logs=dose_logs)

    # Gelecek: sanal planlanmış dozları döndür (DB'ye yazmadan hesaplanır)
    virtual_rows: list[MedicationScheduleDoseResponse] = []
    for med in medications:
        dose_times = await generate_schedule_for_medication_on_date(med, db, target)
        for dt in dose_times:
            synthetic_id = -int(f"{med.id}{dt.strftime('%d%H%M')}")
            virtual_rows.append(
                MedicationScheduleDoseResponse(
                    id=synthetic_id,
                    medication_id=med.id,
                    medication_name=med.name,
                    dosage_form=med.dosage_form,
                    scheduled_time=dt,
                    actual_time=None,
                    status="Planlandı",
                    notes="Henüz vakti gelmedi",
                    is_virtual=True,
                )
            )

    virtual_rows.sort(key=lambda x: x.scheduled_time)
    return MedicationScheduleResponse(date=date_str, mode="future", dose_logs=virtual_rows)


@router.get(
    "/global-search",
    response_model=List[GlobalMedicationSearchResult],
    summary="Global ilaç veritabanında ara (TypeAhead)",
)
async def search_global_medications(
    query: str,
    limit: int = 20,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    ILIKE tabanlı ilaç adı / etkin madde / ATC kodu araması.
    TypeAhead + sonsuz kaydırma için limit/offset destekler.
    En fazla 20 sonuç döner (limit parametresiyle kontrol edilir).
    """
    q = query.strip()
    if len(q) < 2:
        return []
    pattern = f"%{q}%"
    safe_limit = min(max(int(limit), 1), 50)  # 1-50 arasında zorla
    safe_offset = max(int(offset), 0)
    result = await db.execute(
        select(GlobalMedication)
        .where(
            or_(
                GlobalMedication.product_name.ilike(pattern),
                GlobalMedication.active_ingredient.ilike(pattern),
                GlobalMedication.atc_code.ilike(pattern),
            )
        )
        .order_by(GlobalMedication.product_name)
        .limit(safe_limit)
        .offset(safe_offset)
    )
    return result.scalars().all()


@router.put(
    "/{medication_id}",
    response_model=MedicationResponse,
    summary="İlaç güncelle",
)
async def update_medication(
    medication_id: int,
    medication_data: MedicationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Belirtilen ilaç kaydını günceller. Kayıt kullanıcıya ait değilse 404 döner."""
    result = await db.execute(
        select(Medication).where(
            Medication.id == medication_id,
            Medication.user_id == current_user.id,
        )
    )
    medication = result.scalar_one_or_none()
    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlaç bulunamadı.",
        )

    for field, value in medication_data.model_dump(exclude_unset=True).items():
        setattr(medication, field, value)

    await db.commit()
    await db.refresh(medication)
    return medication


@router.delete(
    "/{medication_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="İlaç sil",
)
async def delete_medication(
    medication_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Belirtilen ilaç kaydını siler. Kayıt kullanıcıya ait değilse 404 döner."""
    result = await db.execute(
        select(Medication).where(
            Medication.id == medication_id,
            Medication.user_id == current_user.id,
        )
    )
    medication = result.scalar_one_or_none()
    if not medication:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="İlaç bulunamadı.",
        )

    await db.delete(medication)
    await db.commit()
