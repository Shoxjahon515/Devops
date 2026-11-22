from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings


class Base(DeclarativeBase):
    pass


def make_engine(url: str) -> Engine:
    if url.startswith("sqlite"):
        # SQLite (local dev/tests): allow use from FastAPI's thread pool
        return create_engine(url, connect_args={"check_same_thread": False})
    # PostgreSQL: a pool of reusable connections; pre_ping drops connections
    # that died (e.g. after a database restart) instead of failing a request
    return create_engine(url, pool_size=5, max_overflow=5, pool_pre_ping=True)


engine = make_engine(get_settings().database_url)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    """FastAPI dependency: one session per request, always closed."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
