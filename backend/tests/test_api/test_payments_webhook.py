import asyncio
import json
import os
import time
from dataclasses import dataclass
from hashlib import sha256
import hmac
from typing import Callable
from uuid import UUID, uuid4

from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

os.environ.setdefault("APP_URL", "http://testserver")
os.environ.setdefault("BASE_URL", "http://testserver")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")
os.environ.setdefault("JWT_SECRET_KEY", "secret")
os.environ.setdefault("REVENUECAT_WEBHOOK_AUTH_TOKEN", "token")
os.environ.setdefault("STRIPE_SECRET_KEY", "sk_test")
os.environ.setdefault("STRIPE_WEBHOOK_SECRET", "whsec_test")
os.makedirs("static", exist_ok=True)

from app.api.v1.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402
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


def _create_tables(engine: Engine) -> None:
    User.__table__.create(bind=engine)


def _sign_payload(payload: str, secret: str) -> str:
    timestamp = int(time.time())
    signed_payload = f"{timestamp}.{payload}"
    signature = hmac.new(secret.encode(), signed_payload.encode(), sha256).hexdigest()
    return f"t={timestamp},v1={signature}"


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


async def _create_user(session_maker: SessionFactory, username: str, *, stripe_customer_id: str) -> AuthUser:
    async with session_maker() as session:
        user = User(
            id=uuid4(),
            username=username,
            email=f"{username}@example.com",
            hashed_password="hashed",
            stripe_customer_id=stripe_customer_id,
        )
        session.add(user)
        await session.commit()
        return AuthUser(id=user.id, username=user.username)


def test_checkout_session_completed_updates_user() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            await _create_user(session_maker, "alice", stripe_customer_id="cus_test")
            payload_dict = {
                "id": "evt_1",
                "type": "checkout.session.completed",
                "data": {
                    "object": {
                        "customer": "cus_test",
                        "subscription": "sub_123",
                    }
                },
            }
            payload = json.dumps(payload_dict, separators=(",", ":"))
            signature = _sign_payload(payload, os.environ["STRIPE_WEBHOOK_SECRET"])

            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.post(
                    "/api/v1/payments/webhook",
                    content=payload,
                    headers={
                        "stripe-signature": signature,
                        "content-type": "application/json",
                    },
                )

            assert response.status_code == 200

            async with session_maker() as session:
                result = await session.execute(select(User).where(User.stripe_customer_id == "cus_test"))
                updated_user = result.scalar_one()
                assert updated_user.subscription_level == "gold"
                assert updated_user.stripe_subscription_id == "sub_123"
        finally:
            await _teardown(engine)

    asyncio.run(run_test())


def test_webhook_invalid_signature_returns_400() -> None:
    async def run_test() -> None:
        session_maker, engine = await _setup_test_app()
        try:
            await _create_user(session_maker, "bob", stripe_customer_id="cus_invalid")
            payload_dict = {
                "id": "evt_2",
                "type": "checkout.session.completed",
                "data": {
                    "object": {
                        "customer": "cus_invalid",
                        "subscription": "sub_invalid",
                    }
                },
            }
            payload = json.dumps(payload_dict, separators=(",", ":"))

            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://testserver") as client:
                response = await client.post(
                    "/api/v1/payments/webhook",
                    content=payload,
                    headers={
                        "stripe-signature": "t=0,v1=invalid",
                        "content-type": "application/json",
                    },
                )

            assert response.status_code == 400

            async with session_maker() as session:
                result = await session.execute(select(User).where(User.stripe_customer_id == "cus_invalid"))
                unchanged_user = result.scalar_one()
                assert unchanged_user.subscription_level == "free"
                assert unchanged_user.stripe_subscription_id is None
        finally:
            await _teardown(engine)

    asyncio.run(run_test())
