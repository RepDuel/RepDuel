from __future__ import annotations

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

from app.api.v1.auth import get_current_user  # noqa: E402
from app.api.v1.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.models.routine import Routine  # noqa: E402
from app.models.routine_scenario import RoutineScenario  # noqa: E402
from app.models.routine_submission import (  # noqa: E402
    RoutineScenarioSubmission,
    RoutineSubmission,
)
from app.models.routine_share_snapshot import RoutineShareSnapshot  # noqa: E402
from app.models.scenario import Scenario  # noqa: E402
from app.models.user import User  # noqa: E402


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

    async def delete(self, instance) -> None:
        self._sync_session.delete(instance)


SessionFactory = Callable[[], AsyncSessionWrapper]


def _create_tables(engine: Engine) -> None:
    Scenario.__table__.create(bind=engine)
    User.__table__.create(bind=engine)
    Routine.__table__.create(bind=engine)
    RoutineScenario.__table__.create(bind=engine)
    RoutineSubmission.__table__.create(bind=engine)
    RoutineScenarioSubmission.__table__.create(bind=engine)
    RoutineShareSnapshot.__table__.create(bind=engine)


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


async def _create_scenario(session_maker: SessionFactory, scenario_id: str) -> None:
    async with session_maker() as session:
        scenario = Scenario(
            id=scenario_id,
            name=scenario_id,
            description="Test scenario",
            is_bodyweight=False,
            volume_multiplier=1.0,
        )
        session.add(scenario)
        await session.commit()


async def _create_routine(
    session_maker: SessionFactory,
    *,
    owner_id: UUID,
    scenario_id: str,
) -> UUID:
    async with session_maker() as session:
        routine = Routine(
            id=uuid4(),
            name="Test Routine",
            image_url=None,
            user_id=owner_id,
        )
        session.add(routine)
        await session.flush()
        session.add(
            RoutineScenario(
                routine_id=routine.id,
                scenario_id=scenario_id,
                sets=3,
                reps=10,
            )
        )
        await session.commit()
        return routine.id


async def _set_current_user(user: AuthUser) -> None:
    async def override_current_user() -> AuthUser:
        return user

    app.dependency_overrides[get_current_user] = override_current_user


def test_share_and_import_routine_by_code() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            owner = await _create_user(session_maker, "alice")
            await _create_scenario(session_maker, "pushup")
            routine_id = await _create_routine(
                session_maker, owner_id=owner.id, scenario_id="pushup"
            )
            await _set_current_user(owner)

            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                share_response = await client.post(
                    f"/api/v1/routines/{routine_id}/share"
                )
            assert share_response.status_code == 200
            share_data = share_response.json()
            code = share_data["code"]
            assert code

            # Delete the original routine to ensure the share snapshot persists.
            async with session_maker() as session:
                routine = await session.get(Routine, routine_id)
                if routine is not None:
                    await session.delete(routine)
                    await session.commit()

            # The snapshot should still be retrievable.
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                snapshot_response = await client.get(
                    f"/api/v1/routines/shared/{code}"
                )
            assert snapshot_response.status_code == 200
            snapshot = snapshot_response.json()
            assert snapshot["name"] == "Test Routine"
            assert snapshot["scenarios"][0]["sets"] == 3

            # Import as a different user.
            importer = await _create_user(session_maker, "bob")
            await _set_current_user(importer)

            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                import_response = await client.post(
                    "/api/v1/routines/import",
                    json={"share_code": code},
                )
            assert import_response.status_code == 201
            imported = import_response.json()
            assert imported["name"] == "Test Routine"

            async with session_maker() as session:
                routines = await session.execute(
                    select(Routine.name).where(Routine.user_id == importer.id)
                )
                owned_names = routines.scalars().all()
            assert owned_names == ["Test Routine"]
        finally:
            await _teardown(engine)

    asyncio.run(run_test())
