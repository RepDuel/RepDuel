import asyncio
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable
from uuid import UUID, uuid4

from httpx import ASGITransport, AsyncClient
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

os.environ.setdefault("APP_URL", "http://testserver")
os.environ.setdefault("BASE_URL", "http://testserver")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")
os.environ.setdefault("JWT_SECRET_KEY", "secret")
os.environ.setdefault("REVENUECAT_WEBHOOK_AUTH_TOKEN", "token")
os.environ.setdefault("STRIPE_SECRET_KEY", "sk_test")
os.environ.setdefault("STRIPE_WEBHOOK_SECRET", "whsec_test")

from app.api.v1.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.user_xp import UserXP  # noqa: E402
from app.models.xp_event import XPEvent  # noqa: E402


@dataclass
class AuthUser:
    id: UUID
    username: str


class AsyncSessionWrapper:
    def __init__(self, sync_session: Session) -> None:
        self._sync_session = sync_session

    async def __aenter__(self) -> "AsyncSessionWrapper":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._sync_session.in_transaction():
            self._sync_session.rollback()
        self._sync_session.close()

    async def execute(self, statement):
        return self._sync_session.execute(statement)

    async def scalar(self, statement):
        return self._sync_session.scalar(statement)

    def add(self, instance) -> None:
        self._sync_session.add(instance)

    async def commit(self) -> None:
        self._sync_session.commit()

    async def refresh(self, instance) -> None:
        self._sync_session.refresh(instance)

    async def delete(self, instance) -> None:
        self._sync_session.delete(instance)


SessionFactory = Callable[[], AsyncSessionWrapper]


def _create_tables(engine: Engine) -> None:
    User.__table__.create(bind=engine)
    UserXP.__table__.create(bind=engine)
    XPEvent.__table__.create(bind=engine)


async def _setup_test_app() -> tuple[SessionFactory, Engine]:
    app.dependency_overrides.clear()
    engine = create_engine("sqlite:///:memory:")
    _create_tables(engine)
    sync_maker = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def factory() -> AsyncSessionWrapper:
        return AsyncSessionWrapper(sync_maker())

    async def override_get_db():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    return factory, engine


async def _teardown(engine: Engine) -> None:
    app.dependency_overrides.clear()
    engine.dispose()


async def _create_user(session_maker: SessionFactory, username: str) -> AuthUser:
    async with session_maker() as session:
        user = User(
            id=uuid4(),
            username=username,
            email=f"{username}@example.com",
            hashed_password="hashed",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        session.add(user)
        await session.commit()
        return AuthUser(id=user.id, username=user.username)


def test_level_progress_for_existing_user() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            user = await _create_user(session_maker, "alice")
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.get(f"/api/v1/levels/user/{user.id}")
            assert response.status_code == 200
            payload = response.json()
            assert payload["level"] == 1
            assert payload["xp"] == 0
            assert payload["xp_to_next"] >= 0
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_level_progress_missing_user_returns_404() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            missing_id = uuid4()
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.get(f"/api/v1/levels/user/{missing_id}")
            assert response.status_code == 404
        finally:
            await _teardown(engine)

    asyncio.run(run_test())
