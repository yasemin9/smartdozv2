"""
SmartDoz - Asenkron Veritabanı Bağlantısı (SQLAlchemy + asyncpg)

DATABASE_URL ortam değişkeninden okunur; format:
    postgresql+asyncpg://<user>:<pass>@<host>:<port>/<db>
"""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from core.config import settings

# Asenkron motor — asyncpg sürücüsü
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,       # SQL sorgularını loglamak için True yapın
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

# Asenkron oturum fabrikası
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


class Base(DeclarativeBase):
    """Tüm SQLAlchemy modelleri bu sınıftan türetilir."""
    pass


# ──────────────────────────────────────────────────────
# FastAPI Dependency: Veritabanı Oturumu
# ──────────────────────────────────────────────────────

async def get_db() -> AsyncSession:  # type: ignore[override]
    """
    Her istek için bağımsız bir AsyncSession açar.
    İstek tamamlandığında oturum otomatik kapatılır.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
