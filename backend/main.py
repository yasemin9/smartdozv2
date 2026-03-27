"""
SmartDoz - FastAPI Uygulama Giriş Noktası

Başlatma:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Swagger UI: http://localhost:8000/docs
ReDoc:       http://localhost:8000/redoc
"""
import logging
from contextlib import asynccontextmanager
from datetime import date

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from database import Base, engine
from routers import analytics, ai_interventions, calendar, dose_logs, interactions, medications, notifications, ocr, preferences, summarize, users, voice
from services.decision_engine import decision_engine as ai_decision_engine
from services.interaction_engine import interaction_engine
from services.scheduler import create_daily_dose_logs, setup_scheduler

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Uygulama yaşam döngüsü:
    1. DB tablolarını oluştur
    2. Bugünün doz loglarını oluştur
    3. APScheduler'ı başlat (RabbitMQ simülasyonu — EK1_revize.pdf s.27)
    """
    # 1. Tablolar
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        # Legacy DB uyumluluğu: medications tablosuna Modül 3 metadata kolonları eklenir.
        await conn.execute(
            text("ALTER TABLE medications ADD COLUMN IF NOT EXISTS active_ingredient TEXT")
        )
        await conn.execute(
            text("ALTER TABLE medications ADD COLUMN IF NOT EXISTS atc_code VARCHAR(20)")
        )
        await conn.execute(
            text("ALTER TABLE medications ADD COLUMN IF NOT EXISTS barcode VARCHAR(50)")
        )
        # Modül 7: Davranış analizi için was_postponed bayrağı
        await conn.execute(
            text("ALTER TABLE dose_logs ADD COLUMN IF NOT EXISTS was_postponed BOOLEAN NOT NULL DEFAULT FALSE")
        )
        # Modül 8: ai_decisions tablosu Base.metadata.create_all tarafından yukarıda
        # otomatik olarak oluşturuldu (AIDecision ORM modeli tanımından).

    # 2. Modül 3 — İlaç Etkileşim Motoru: CSV'yi startup'ta belleğe yükle
    try:
        interaction_engine.load()
        logger.info("InteractionEngine (Modül 3) başarıyla yüklendi.")
    except Exception as exc:
        logger.error(f"InteractionEngine yüklenemedi: {exc}")

    # Modül 8 — DecisionEngine hazır (stateless, no preload needed)
    logger.info("DecisionEngine (Modül 8) hazır.")

    # 3. Bugünkü loglar (startup lazy creation)
    try:
        await create_daily_dose_logs(date.today())
        logger.info("Başlangıç doz logları hazır.")
    except Exception as exc:
        logger.warning(f"Başlangıç doz log oluşturma: {exc}")

    # 4. Zamanlayıcı
    sched = setup_scheduler()
    sched.start()
    logger.info("APScheduler başlatıldı.")

    yield

    sched.shutdown(wait=False)
    logger.info("APScheduler durduruldu.")


app = FastAPI(
    title="SmartDoz API",
    description="Akıllı İlaç Takip Sistemi — Modül 1–8",
    version="8.0.0",
    lifespan=lifespan,
)

# ──────────────────────────────────────────────────────
# CORS — Flutter Web uygulamasının API'ye erişmesi için
# Production'da allow_origins değerini kısıtlayın!
# ──────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:4200",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://localhost:52000",
        "http://localhost:52001",
        "http://127.0.0.1:8080",
    ],
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Router'ları kaydet
app.include_router(users.router)
app.include_router(medications.router)
app.include_router(interactions.router)
app.include_router(analytics.router)
app.include_router(ocr.router)
app.include_router(calendar.router)
app.include_router(dose_logs.router)
app.include_router(preferences.router)
app.include_router(notifications.router)
app.include_router(ai_interventions.router)
app.include_router(summarize.router)
app.include_router(voice.router)


@app.get("/health", tags=["Sistem"])
async def health_check():
    """Servis sağlık kontrolü."""
    return {"status": "healthy", "service": "SmartDoz API", "version": "2.0.0"}
