import asyncio
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
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

from app.api.v1.auth import get_current_user  # noqa: E402
from app.api.v1.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.models.quest import (  # noqa: E402
    QuestCadence,
    QuestMetric,
    QuestStatus,
    QuestTemplate,
    UserQuest,
)
from app.models.daily_workout_aggregate import DailyWorkoutAggregate  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.user_xp import UserXP  # noqa: E402
from app.models.xp_event import XPEvent  # noqa: E402
from app.services.quest_service import (  # noqa: E402
    claim_user_quest,
    get_user_quests,
    record_workout_completion,
)


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

    def add_all(self, instances) -> None:
        self._sync_session.add_all(list(instances))

    async def commit(self) -> None:
        self._sync_session.commit()

    async def flush(self, objects=None) -> None:
        self._sync_session.flush(objects)

    async def refresh(self, instance, attribute_names=None) -> None:
        self._sync_session.refresh(instance, attribute_names=attribute_names)

    async def rollback(self) -> None:
        self._sync_session.rollback()


SessionFactory = Callable[[], AsyncSessionWrapper]


async def _setup_test_app() -> tuple[SessionFactory, Engine]:
    app.dependency_overrides.clear()
    engine = create_engine("sqlite:///:memory:")
    User.__table__.create(bind=engine)
    XPEvent.__table__.create(bind=engine)
    UserXP.__table__.create(bind=engine)
    QuestTemplate.__table__.create(bind=engine)
    UserQuest.__table__.create(bind=engine)
    DailyWorkoutAggregate.__table__.create(bind=engine)

    sync_maker = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def factory() -> AsyncSessionWrapper:
        return AsyncSessionWrapper(sync_maker())

    async def override_get_db():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    return factory, engine


async def _create_user(session_maker: SessionFactory, username: str) -> AuthUser:
    async with session_maker() as session:
        user = User(
            id=uuid4(),
            username=username,
            email=f"{username}@example.com",
            hashed_password="hashed",
        )
        session.add(user)
        await session.commit()
        return AuthUser(id=user.id, username=user.username)


async def _create_template(
    session_maker: SessionFactory,
    *,
    code: str,
    cadence: QuestCadence,
    metric: QuestMetric,
    target_value: int,
    reward_xp: int,
    auto_claim: bool,
    available_from: datetime,
) -> UUID:
    async with session_maker() as session:
        template = QuestTemplate(
            code=code,
            title=code.replace("_", " ").title(),
            description=f"Complete {target_value} {metric.value.replace('_', ' ')}",
            cadence=cadence.value,
            metric=metric.value,
            target_value=target_value,
            reward_xp=reward_xp,
            auto_claim=auto_claim,
            available_from=available_from,
            is_active=True,
        )
        session.add(template)
        await session.commit()
        return template.id


async def _set_current_user(user: AuthUser) -> None:
    async def override_current_user() -> AuthUser:
        return user

    app.dependency_overrides[get_current_user] = override_current_user


async def _teardown(engine: Engine) -> None:
    app.dependency_overrides.clear()
    engine.dispose()


def test_daily_quest_completion_awards_xp() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        now = datetime(2025, 1, 1, tzinfo=timezone.utc)
        try:
            user = await _create_user(session_maker, "alice")
            await _create_template(
                session_maker,
                code="daily_30_min_workout",
                cadence=QuestCadence.DAILY,
                metric=QuestMetric.ACTIVE_MINUTES,
                target_value=30,
                reward_xp=100,
                auto_claim=True,
                available_from=now - timedelta(days=1),
            )
            async with session_maker() as session:
                quests = await get_user_quests(session, user.id, now=now)
                assert len(quests) == 1
                quest = quests[0]
                assert quest.status == QuestStatus.ACTIVE.value
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=32,
                    completed_at=now,
                    now=now,
                )
                quests = await get_user_quests(session, user.id, now=now)
                quest = quests[0]
                assert quest.status == QuestStatus.CLAIMED.value
                assert quest.progress_value == quest.required_value == 30
                result = await session.execute(
                    select(UserXP).where(UserXP.user_id == user.id)
                )
                summary = result.scalars().first()
                assert summary is not None
                assert summary.total_xp == 100
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_daily_quest_requires_single_session() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        now = datetime(2025, 2, 1, 8, tzinfo=timezone.utc)
        try:
            user = await _create_user(session_maker, "casey")
            await _create_template(
                session_maker,
                code="daily_30_min_workout",
                cadence=QuestCadence.DAILY,
                metric=QuestMetric.ACTIVE_MINUTES,
                target_value=30,
                reward_xp=100,
                auto_claim=True,
                available_from=now - timedelta(days=1),
            )
            async with session_maker() as session:
                quests = await get_user_quests(session, user.id, now=now)
                quest = quests[0]
                assert quest.status == QuestStatus.ACTIVE.value
                assert quest.progress_value == 0

                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=20,
                    completed_at=now,
                    now=now,
                )
                quests = await get_user_quests(session, user.id, now=now)
                quest = quests[0]
                assert quest.status == QuestStatus.ACTIVE.value
                assert quest.progress_value == 20

                later_same_day = now + timedelta(hours=3)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=12,
                    completed_at=later_same_day,
                    now=later_same_day,
                )
                quests = await get_user_quests(session, user.id, now=later_same_day)
                quest = quests[0]
                assert quest.status == QuestStatus.ACTIVE.value
                # Progress should still reflect the single longest session (20 minutes).
                assert quest.progress_value == 20

                evening = now + timedelta(hours=10)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=35,
                    completed_at=evening,
                    now=evening,
                )
                quests = await get_user_quests(session, user.id, now=evening)
                quest = quests[0]
                assert quest.status == QuestStatus.CLAIMED.value
                assert quest.progress_value == 30
                result = await session.execute(
                    select(UserXP).where(UserXP.user_id == user.id)
                )
                summary = result.scalars().first()
                assert summary is not None
                assert summary.total_xp == 100
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_weekly_quest_requires_three_distinct_days() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        monday = datetime(2025, 3, 3, 6, tzinfo=timezone.utc)
        try:
            user = await _create_user(session_maker, "devon")
            await _create_template(
                session_maker,
                code="weekly_30_min_workout_three_days",
                cadence=QuestCadence.WEEKLY,
                metric=QuestMetric.WORKOUTS_COMPLETED,
                target_value=3,
                reward_xp=300,
                auto_claim=False,
                available_from=monday - timedelta(days=7),
            )
            async with session_maker() as session:
                quests = await get_user_quests(session, user.id, now=monday)
                quest = quests[0]
                assert quest.status == QuestStatus.ACTIVE.value
                assert quest.progress_value == 0

                # First qualifying day (Monday).
                first_day_time = monday + timedelta(hours=1)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=35,
                    completed_at=first_day_time,
                    now=first_day_time,
                )
                quests = await get_user_quests(session, user.id, now=first_day_time)
                quest = quests[0]
                assert quest.progress_value == 1
                assert quest.status == QuestStatus.ACTIVE.value

                # Additional workout the same day should not increase the day count.
                second_same_day = monday + timedelta(hours=5)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=40,
                    completed_at=second_same_day,
                    now=second_same_day,
                )
                quests = await get_user_quests(session, user.id, now=second_same_day)
                quest = quests[0]
                assert quest.progress_value == 1

                # Second qualifying day (Tuesday) with an initial short session that shouldn't count.
                tuesday = monday + timedelta(days=1)
                short_session = tuesday + timedelta(hours=2)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=25,
                    completed_at=short_session,
                    now=short_session,
                )
                quests = await get_user_quests(session, user.id, now=short_session)
                quest = quests[0]
                assert quest.progress_value == 1

                qualifying_tuesday = tuesday + timedelta(hours=4)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=33,
                    completed_at=qualifying_tuesday,
                    now=qualifying_tuesday,
                )
                quests = await get_user_quests(session, user.id, now=qualifying_tuesday)
                quest = quests[0]
                assert quest.progress_value == 2

                # Third qualifying day (Thursday).
                thursday = monday + timedelta(days=3)
                qualifying_thursday = thursday + timedelta(hours=3)
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=31,
                    completed_at=qualifying_thursday,
                    now=qualifying_thursday,
                )
                quests = await get_user_quests(session, user.id, now=qualifying_thursday)
                quest = quests[0]
                assert quest.progress_value == 3
                assert quest.required_value == 3
                assert quest.status == QuestStatus.COMPLETED.value

                await claim_user_quest(session, user.id, quest.id, now=qualifying_thursday)
                quests = await get_user_quests(session, user.id, now=qualifying_thursday)
                quest = quests[0]
                assert quest.status == QuestStatus.CLAIMED.value
                result = await session.execute(
                    select(UserXP).where(UserXP.user_id == user.id)
                )
                summary = result.scalars().first()
                assert summary is not None
                assert summary.total_xp == 300
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_manual_claim_flow() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        now = datetime(2025, 5, 5, tzinfo=timezone.utc)
        try:
            user = await _create_user(session_maker, "bob")
            await _create_template(
                session_maker,
                code="weekly_minutes",
                cadence=QuestCadence.WEEKLY,
                metric=QuestMetric.ACTIVE_MINUTES,
                target_value=30,
                reward_xp=75,
                auto_claim=False,
                available_from=now - timedelta(days=7),
            )
            async with session_maker() as session:
                quests = await get_user_quests(session, user.id, now=now)
                assert len(quests) == 1
                quest = quests[0]
                assert quest.status == QuestStatus.ACTIVE.value
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=30,
                    completed_at=now,
                    now=now,
                )
                quests = await get_user_quests(session, user.id, now=now)
                quest = quests[0]
                assert quest.status == QuestStatus.COMPLETED.value
                result = await session.execute(
                    select(UserXP).where(UserXP.user_id == user.id)
                )
                summary = result.scalars().first()
                assert summary is None or summary.total_xp == 0
                await claim_user_quest(session, user.id, quest.id, now=now)
                quests = await get_user_quests(session, user.id, now=now)
                quest = quests[0]
                assert quest.status == QuestStatus.CLAIMED.value
                result = await session.execute(
                    select(UserXP).where(UserXP.user_id == user.id)
                )
                summary = result.scalars().first()
                assert summary is not None
                assert summary.total_xp == 75
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_quest_api_endpoints() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        now = datetime.now(timezone.utc)
        daily_reward = 20
        weekly_reward = 60
        try:
            user = await _create_user(session_maker, "chris")
            await _set_current_user(user)
            await _create_template(
                session_maker,
                code="daily_cardio",
                cadence=QuestCadence.DAILY,
                metric=QuestMetric.WORKOUTS_COMPLETED,
                target_value=1,
                reward_xp=daily_reward,
                auto_claim=True,
                available_from=now - timedelta(days=1),
            )
            await _create_template(
                session_maker,
                code="weekly_duration",
                cadence=QuestCadence.WEEKLY,
                metric=QuestMetric.ACTIVE_MINUTES,
                target_value=45,
                reward_xp=weekly_reward,
                auto_claim=False,
                available_from=now - timedelta(days=7),
            )
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.get("/api/v1/quests/me")
                assert response.status_code == 200
                payload = response.json()
                assert "quests" in payload
                assert len(payload["quests"]) == 2
            async with session_maker() as session:
                await record_workout_completion(
                    session,
                    user.id,
                    duration_minutes=50,
                    completed_at=now,
                    now=now,
                )
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.get("/api/v1/quests/me")
                assert response.status_code == 200
                payload = response.json()
                manual = next(
                    quest for quest in payload["quests"] if quest["template"]["metric"] == "active_minutes"
                )
                assert manual["status"] == "completed"
                quest_id = manual["id"]
                claim_response = await client.post(f"/api/v1/quests/me/{quest_id}/claim")
                assert claim_response.status_code == 200
                claimed = claim_response.json()
                assert claimed["status"] == "claimed"
            async with session_maker() as session:
                result = await session.execute(
                    select(UserXP.total_xp).where(UserXP.user_id == user.id)
                )
                total_xp = result.scalar() or 0
                assert total_xp == daily_reward + weekly_reward
        finally:
            await _teardown(engine)

    asyncio.run(run_test())

