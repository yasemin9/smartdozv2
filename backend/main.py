"""
SmartDoz - FastAPI Uygulama Giriş Noktası

Başlatma:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Swagger UI: http://localhost:8000/docs
ReDoc:       http://localhost:8000/redoc
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import Base, engine
from routers import medications, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Uygulama başlangıcında veritabanı tablolarını oluşturur.
    Production ortamında Alembic migration kullanınız.
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="SmartDoz API",
    description="Akıllı İlaç Takip Sistemi — Kullanıcı & İlaç Yönetimi",
    version="1.0.0",
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

# Router'ları kaydet
app.include_router(users.router)
app.include_router(medications.router)


@app.get("/health", tags=["Sistem"])
async def health_check():
    """Servis sağlık kontrolü."""
    return {"status": "healthy", "service": "SmartDoz API", "version": "1.0.0"}
