# backend/tests/test_api/test_scores_api.py

import asyncio
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable
from uuid import UUID, uuid4

from httpx import ASGITransport, AsyncClient
from sqlalchemy import create_engine, select
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

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
from app.api.v1.score import calculate_score_value  # noqa: E402
from app.main import app  # noqa: E402
from app.models.personal_best_event import PersonalBestEvent  # noqa: E402
from app.models.scenario import Scenario  # noqa: E402
from app.models.score import Score  # noqa: E402
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

    async def get(self, model, ident):
        return self._sync_session.get(model, ident)

    def add(self, instance) -> None:
        self._sync_session.add(instance)

    async def commit(self) -> None:
        self._sync_session.commit()

    async def refresh(self, instance) -> None:
        self._sync_session.refresh(instance)

    async def flush(self) -> None:
        self._sync_session.flush()

    async def rollback(self) -> None:
        self._sync_session.rollback()


SessionFactory = Callable[[], AsyncSessionWrapper]


def _create_tables(engine: Engine) -> None:
    Scenario.__table__.create(bind=engine)
    User.__table__.create(bind=engine)
    UserXP.__table__.create(bind=engine)
    XPEvent.__table__.create(bind=engine)
    Score.__table__.create(bind=engine)
    PersonalBestEvent.__table__.create(bind=engine)


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
    if _created_static and STATIC_DIR.exists():
        try:
            STATIC_DIR.rmdir()
        except OSError:
            pass


async def _create_user(session_maker: SessionFactory, username: str, *, weight: float) -> AuthUser:
    async with session_maker() as session:
        user = User(
            id=uuid4(),
            username=username,
            email=f"{username}@example.com",
            hashed_password="hashed",
            weight=weight,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        session.add(user)
        await session.commit()
        return AuthUser(id=user.id, username=user.username)


async def _create_scenario(
    session_maker: SessionFactory,
    scenario_id: str,
    *,
    is_bodyweight: bool = False,
    volume_multiplier: float = 1.0,
) -> None:
    async with session_maker() as session:
        scenario = Scenario(
            id=scenario_id,
            name=scenario_id,
            description="Test scenario",
            is_bodyweight=is_bodyweight,
            volume_multiplier=volume_multiplier,
        )
        session.add(scenario)
        await session.commit()


async def _create_existing_score(
    session_maker: SessionFactory,
    *,
    user_id: UUID,
    scenario_id: str,
    weight_lifted: float,
    reps: int | None = None,
    sets: int | None = None,
    is_bodyweight: bool = False,
) -> None:
    async with session_maker() as session:
        score_value = calculate_score_value(weight_lifted, reps, is_bodyweight=is_bodyweight)
        score = Score(
            user_id=user_id,
            scenario_id=scenario_id,
            weight_lifted=weight_lifted,
            reps=reps,
            sets=sets,
            score_value=score_value,
            is_bodyweight=is_bodyweight,
        )
        session.add(score)
        await session.commit()


def test_volume_xp_awarded_for_score() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            user = await _create_user(session_maker, "volume_user", weight=90.0)
            await _create_scenario(session_maker, "test_strength")
            await _create_existing_score(
                session_maker,
                user_id=user.id,
                scenario_id="test_strength",
                weight_lifted=200.0,
                reps=1,
                sets=1,
            )

            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.post(
                    "/api/v1/scores/scenario/test_strength/",
                    json={
                        "user_id": str(user.id),
                        "weight_lifted": 180.0,
                        "reps": 1,
                        "sets": 1,
                    },
                )

            assert response.status_code == 200
            payload = response.json()
            assert payload["is_personal_best"] is False

            async with session_maker() as session:
                xp_result = await session.execute(select(UserXP).where(UserXP.user_id == user.id))
                summary = xp_result.scalars().first()
                assert summary is not None
                assert summary.total_xp == 2

                event_result = await session.execute(select(XPEvent).where(XPEvent.user_id == user.id))
                events = event_result.scalars().all()
                assert len(events) == 1
                assert events[0].amount == 2
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_personal_best_awards_bonus_xp() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            user = await _create_user(session_maker, "pr_user", weight=90.0)
            await _create_scenario(session_maker, "test_pr")

            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.post(
                    "/api/v1/scores/scenario/test_pr/",
                    json={
                        "user_id": str(user.id),
                        "weight_lifted": 45.0,
                        "reps": 1,
                        "sets": 1,
                    },
                )

            assert response.status_code == 200
            payload = response.json()
            assert payload["is_personal_best"] is True

            async with session_maker() as session:
                xp_result = await session.execute(select(UserXP).where(UserXP.user_id == user.id))
                summary = xp_result.scalars().first()
                assert summary is not None
                assert summary.total_xp == 10

                event_result = await session.execute(select(XPEvent).where(XPEvent.user_id == user.id))
                events = event_result.scalars().all()
                assert len(events) == 1
                assert events[0].amount == 10
        finally:
            await _teardown(engine)

    asyncio.run(run_test())

