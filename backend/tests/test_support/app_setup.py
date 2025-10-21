"""Helpers for configuring the FastAPI app in tests."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Callable, Iterable

from httpx import ASGITransport, AsyncClient
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.sql.schema import Table

os.environ.setdefault("APP_URL", "http://testserver")
os.environ.setdefault("BASE_URL", "http://testserver")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")
os.environ.setdefault("JWT_SECRET_KEY", "secret")
os.environ.setdefault("REVENUECAT_WEBHOOK_AUTH_TOKEN", "token")
os.environ.setdefault("STRIPE_SECRET_KEY", "sk_test")
os.environ.setdefault("STRIPE_WEBHOOK_SECRET", "whsec_test")

PROJECT_ROOT = Path(__file__).resolve().parents[3]
STATIC_DIR = PROJECT_ROOT / "static"
_created_static = False
if not STATIC_DIR.exists():
    STATIC_DIR.mkdir()
    _created_static = True

from app.api.v1.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402


class AsyncSessionWrapper:
    """Light-weight async facade around a synchronous SQLAlchemy session."""

    def __init__(self, sync_session: Session) -> None:
        self._sync_session = sync_session

    async def __aenter__(self) -> "AsyncSessionWrapper":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:  # pragma: no cover - defensive
        if self._sync_session.in_transaction():
            self._sync_session.rollback()
        self._sync_session.close()

    async def execute(self, statement):
        return self._sync_session.execute(statement)

    async def get(self, model, ident):
        return self._sync_session.get(model, ident)

    def add(self, instance) -> None:
        self._sync_session.add(instance)

    def add_all(self, instances) -> None:
        self._sync_session.add_all(instances)

    async def commit(self) -> None:
        self._sync_session.commit()

    async def refresh(self, instance) -> None:
        self._sync_session.refresh(instance)

    async def flush(self) -> None:
        self._sync_session.flush()

    async def delete(self, instance) -> None:
        self._sync_session.delete(instance)

    async def rollback(self) -> None:
        self._sync_session.rollback()


SessionFactory = Callable[[], AsyncSessionWrapper]


def setup_test_app(tables: Iterable[Table]) -> tuple[SessionFactory, Engine]:
    """Return a configured ``SessionFactory`` and engine for API tests."""

    app.dependency_overrides.clear()
    engine = create_engine("sqlite:///:memory:", future=True)
    for table in tables:
        table.create(bind=engine)

    sync_maker = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def factory() -> AsyncSessionWrapper:
        return AsyncSessionWrapper(sync_maker())

    async def override_get_db():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    return factory, engine


async def teardown_test_app(engine: Engine) -> None:
    """Reset dependency overrides and dispose the temporary engine."""

    app.dependency_overrides.clear()
    engine.dispose()
    if _created_static and STATIC_DIR.exists():
        try:
            STATIC_DIR.rmdir()
        except OSError:  # pragma: no cover - directory not empty
            pass


def api_client() -> AsyncClient:
    """Return an ``AsyncClient`` wired to the FastAPI application."""

    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://testserver")
