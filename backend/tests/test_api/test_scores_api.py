# backend/tests/test_api/test_scores_api.py

import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.engine import Engine

from tests.test_support.app_setup import (
    SessionFactory,
    api_client,
    setup_test_app,
    teardown_test_app,
)
from app.api.v1.auth import get_current_user  # noqa: E402
from app.main import app  # noqa: E402
from app.models.personal_best_event import PersonalBestEvent  # noqa: E402
from app.models.scenario import Scenario  # noqa: E402
from app.models.score import Score  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.user_xp import UserXP  # noqa: E402
from app.models.xp_event import XPEvent  # noqa: E402
from app.services.score_service import calculate_score_value  # noqa: E402


@dataclass
class AuthUser:
    id: UUID
    username: str


async def _set_current_user(user: AuthUser) -> None:
    async def override_current_user() -> AuthUser:
        return user

    app.dependency_overrides[get_current_user] = override_current_user


_TABLES = [
    Scenario.__table__,
    User.__table__,
    UserXP.__table__,
    XPEvent.__table__,
    Score.__table__,
    PersonalBestEvent.__table__,
]


def _setup_test_app() -> tuple[SessionFactory, Engine]:
    return setup_test_app(_TABLES)


async def _teardown(engine: Engine) -> None:
    await teardown_test_app(engine)


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
        session_maker, engine = _setup_test_app()
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

            await _set_current_user(user)
            async with api_client() as client:
                response = await client.post(
                    "/api/v1/scores/scenario/test_strength/",
                    json={
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
        session_maker, engine = _setup_test_app()
        try:
            user = await _create_user(session_maker, "pr_user", weight=90.0)
            await _create_scenario(session_maker, "test_pr")

            await _set_current_user(user)
            async with api_client() as client:
                response = await client.post(
                    "/api/v1/scores/scenario/test_pr/",
                    json={
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


def test_create_score_requires_authentication() -> None:
    async def run_test() -> None:
        session_maker, engine = _setup_test_app()
        try:
            await _create_user(session_maker, "unauth_user", weight=75.0)
            await _create_scenario(session_maker, "test_auth")

            async with api_client() as client:
                response = await client.post(
                    "/api/v1/scores/scenario/test_auth/",
                    json={
                        "weight_lifted": 100.0,
                        "reps": 1,
                    },
                )

            assert response.status_code == 401
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_delete_scores_requires_owner() -> None:
    async def run_test() -> None:
        session_maker, engine = _setup_test_app()
        try:
            owner = await _create_user(session_maker, "deleter", weight=85.0)
            other = await _create_user(session_maker, "other", weight=90.0)
            await _create_scenario(session_maker, "delete_scenario")
            await _create_existing_score(
                session_maker,
                user_id=owner.id,
                scenario_id="delete_scenario",
                weight_lifted=140.0,
                reps=1,
            )

            # Attempt deletion as another user should fail.
            await _set_current_user(other)
            async with api_client() as client:
                forbidden = await client.delete(f"/api/v1/scores/user/{owner.id}")
            assert forbidden.status_code == 403

            # Owner can delete their own scores.
            await _set_current_user(owner)
            async with api_client() as client:
                success = await client.delete(f"/api/v1/scores/user/{owner.id}")
            assert success.status_code == 204

            async with session_maker() as session:
                result = await session.execute(select(Score).where(Score.user_id == owner.id))
                remaining = result.scalars().all()
                assert not remaining
        finally:
            await _teardown(engine)

    asyncio.run(run_test())

