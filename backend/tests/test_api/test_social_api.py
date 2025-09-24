import asyncio
import os
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

from httpx import ASGITransport, AsyncClient
from sqlalchemy import create_engine, func, select
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
from app.api.v1.social import follow_rate_limiter  # noqa: E402
from app.main import app  # noqa: E402
from app.models.social import SocialEdge  # noqa: E402
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


async def _setup_test_app() -> tuple[SessionFactory, Engine]:
    app.dependency_overrides.clear()
    engine = create_engine("sqlite:///:memory:")
    User.__table__.create(bind=engine)
    SocialEdge.__table__.create(bind=engine)
    sync_maker = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def factory() -> AsyncSessionWrapper:
        return AsyncSessionWrapper(sync_maker())

    async def override_get_db():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    follow_rate_limiter.reset()
    return factory, engine


async def _create_user(
    session_maker: SessionFactory, username: str, display_name: str | None = None
) -> AuthUser:
    async with session_maker() as session:
        user = User(
            id=uuid4(),
            username=username,
            email=f"{username}@example.com",
            hashed_password="hashed",
            display_name=display_name,
        )
        session.add(user)
        await session.commit()
        user_id = user.id
        user_name = user.username
        return AuthUser(id=user_id, username=user_name)


async def _add_edge(
    session_maker: SessionFactory,
    follower_id: UUID,
    followee_id: UUID,
    created_at: datetime,
) -> None:
    async with session_maker() as session:
        edge = SocialEdge(
            follower_id=follower_id,
            followee_id=followee_id,
            status="active",
            created_at=created_at,
        )
        session.add(edge)
        await session.commit()


async def _set_current_user(user: AuthUser) -> None:
    async def override_current_user() -> AuthUser:
        return user

    app.dependency_overrides[get_current_user] = override_current_user


async def _teardown(engine: Engine) -> None:
    app.dependency_overrides.clear()
    engine.dispose()


def test_self_follow_rejected() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            user = await _create_user(session_maker, "alice")
            await _set_current_user(user)
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.post(f"/api/v1/users/{user.id}/follow")
            assert response.status_code == 409
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_follow_unfollow_idempotent() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            follower = await _create_user(session_maker, "alice")
            target = await _create_user(session_maker, "bob")
            await _set_current_user(follower)
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                first = await client.post(f"/api/v1/users/{target.id}/follow")
                second = await client.post(f"/api/v1/users/{target.id}/follow")
                assert first.status_code == 204
                assert second.status_code == 204
                delete_first = await client.delete(f"/api/v1/users/{target.id}/follow")
                delete_second = await client.delete(f"/api/v1/users/{target.id}/follow")
                assert delete_first.status_code == 204
                assert delete_second.status_code == 204
            async with session_maker() as session:
                total_edges = await session.scalar(select(func.count()).select_from(SocialEdge))
                assert total_edges == 0
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_followers_pagination() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            target = await _create_user(session_maker, "target")
            await _set_current_user(target)
            now = datetime.now(timezone.utc)
            followers: list[AuthUser] = []
            for idx in range(5):
                follower = await _create_user(session_maker, f"follower{idx}")
                followers.append(follower)
                await _add_edge(
                    session_maker,
                    follower.id,
                    target.id,
                    now + timedelta(minutes=idx),
                )
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                first_page = await client.get(
                    f"/api/v1/users/{target.id}/followers",
                    params={"offset": 0, "limit": 2},
                )
                second_page = await client.get(
                    f"/api/v1/users/{target.id}/followers",
                    params={"offset": 4, "limit": 2},
                )
            assert first_page.status_code == 200
            data = first_page.json()
            assert data["count"] == 2
            assert data["total"] == 5
            assert data["offset"] == 0
            assert data["next_offset"] == 2
            assert data["items"][0]["id"] == str(followers[-1].id)
            assert data["items"][0]["is_following"] is False
            assert data["items"][0]["is_followed_by"] is True
            assert data["items"][0]["is_friend"] is False
            assert data["items"][0]["is_self"] is False
            assert data["items"][1]["id"] == str(followers[-2].id)
            assert data["items"][1]["is_following"] is False
            assert data["items"][1]["is_followed_by"] is True
            assert data["items"][1]["is_friend"] is False
            assert data["items"][1]["is_self"] is False

            assert second_page.status_code == 200
            second_data = second_page.json()
            assert second_data["count"] == 1
            assert second_data["total"] == 5
            assert second_data["offset"] == 4
            assert second_data["next_offset"] is None
            assert second_data["items"][0]["id"] == str(followers[0].id)
            assert second_data["items"][0]["is_following"] is False
            assert second_data["items"][0]["is_followed_by"] is True
            assert second_data["items"][0]["is_friend"] is False
            assert second_data["items"][0]["is_self"] is False
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_mutuals_compute_correctly() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            user_a = await _create_user(session_maker, "alpha")
            user_b = await _create_user(session_maker, "bravo")
            user_c = await _create_user(session_maker, "charlie")
            user_d = await _create_user(session_maker, "delta")
            await _set_current_user(user_a)
            now = datetime.now(timezone.utc)
            await _add_edge(session_maker, user_a.id, user_b.id, now)
            await _add_edge(session_maker, user_b.id, user_a.id, now + timedelta(seconds=1))
            await _add_edge(session_maker, user_a.id, user_c.id, now + timedelta(seconds=2))
            await _add_edge(session_maker, user_d.id, user_a.id, now + timedelta(seconds=3))
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.get(f"/api/v1/users/{user_a.id}/friends")
            assert response.status_code == 200
            data = response.json()
            assert data["total"] == 1
            assert data["count"] == 1
            assert data["offset"] == 0
            assert data["next_offset"] is None
            assert [item["id"] for item in data["items"]] == [str(user_b.id)]
            assert data["items"][0]["is_following"] is True
            assert data["items"][0]["is_followed_by"] is True
            assert data["items"][0]["is_friend"] is True
            assert data["items"][0]["is_self"] is False
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_search_users_returns_relationship_flags() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            viewer = await _create_user(session_maker, "viewer")
            friend = await _create_user(
                session_maker, "friend", display_name="Friendly"
            )
            fan = await _create_user(session_maker, "fan", display_name="Fan Girl")
            await _create_user(session_maker, "other")

            await _set_current_user(viewer)
            now = datetime.now(timezone.utc)
            await _add_edge(session_maker, viewer.id, friend.id, now)
            await _add_edge(session_maker, fan.id, viewer.id, now + timedelta(seconds=1))

            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                first_page = await client.get(
                    "/api/v1/users/lookup", params={"q": "f", "limit": 1}
                )
                second_page = await client.get(
                    "/api/v1/users/lookup", params={"q": "f", "offset": 1, "limit": 1}
                )
                self_page = await client.get(
                    "/api/v1/users/lookup", params={"q": "viewer"}
                )

            assert first_page.status_code == 200
            data = first_page.json()
            assert data["count"] == 1
            assert data["total"] == 2
            assert data["offset"] == 0
            assert data["next_offset"] == 1
            assert data["items"][0]["id"] == str(fan.id)
            assert data["items"][0]["display_name"] == "Fan Girl"
            assert data["items"][0]["is_following"] is False
            assert data["items"][0]["is_followed_by"] is True
            assert data["items"][0]["is_friend"] is False
            assert data["items"][0]["is_self"] is False

            assert second_page.status_code == 200
            second = second_page.json()
            assert second["count"] == 1
            assert second["total"] == 2
            assert second["offset"] == 1
            assert second["next_offset"] is None
            assert second["items"][0]["id"] == str(friend.id)
            assert second["items"][0]["display_name"] == "Friendly"
            assert second["items"][0]["is_following"] is True
            assert second["items"][0]["is_followed_by"] is False
            assert second["items"][0]["is_friend"] is False
            assert second["items"][0]["is_self"] is False

            assert self_page.status_code == 200
            self_data = self_page.json()
            assert self_data["total"] == 0
            assert self_data["items"] == []
        finally:
            await _teardown(engine)

    asyncio.run(run_test())
