"""
Tek seferlik araç: PENDING AIDecision kayıtlarının explanation alanını
güncel tavsiye diliyle yeniden üretip kaydeder.

Çalıştırma (venv aktifken backend/ klasöründen):
    python fix_pending_explanations.py
"""
import asyncio
import sys
import os

# backend/ klasörünü path'e ekle (import için)
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy import select, update
from database import AsyncSessionLocal
from models import AIDecision
from services.decision_engine import _generate_xai_explanation


def _rebuild_explanation(d: AIDecision) -> str:
    """Kaydın payload bilgilerinden açıklamayı yeniden üretir."""
    raw = d.payload or {}
    import json
    payload: dict = json.loads(raw) if isinstance(raw, str) else raw
    skip_reason   = payload.get("reason", "")
    delta_minutes = int(payload.get("delta_minutes", 0))
    avg_delay     = float(payload.get("avg_delay_minutes", payload.get("avg_delay", 0.0)))
    overall_score = float(payload.get("overall_score", 0.0))

    return _generate_xai_explanation(
        window        = d.time_window or "all",
        decision_type = d.decision_type,
        delta_minutes = delta_minutes,
        avg_delay     = avg_delay,
        overall_score = overall_score,
        skip_reason   = skip_reason,
    )


async def main() -> None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(AIDecision).where(AIDecision.status == "PENDING")
        )
        pending = result.scalars().all()

        if not pending:
            print("Güncellenecek PENDING karar bulunamadı.")
            return

        updated = 0
        for d in pending:
            new_explanation = _rebuild_explanation(d)
            if new_explanation != d.explanation:
                d.explanation = new_explanation
                updated += 1

        await db.commit()
        print(f"Toplam {len(pending)} PENDING karar tarandı, {updated} tanesi güncellendi.")


if __name__ == "__main__":
    asyncio.run(main())
