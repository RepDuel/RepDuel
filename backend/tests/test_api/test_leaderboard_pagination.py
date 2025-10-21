# backend/tests/test_api/test_leaderboard_pagination.py

import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from tests.test_support.app_setup import (
    api_client,
    setup_test_app,
    teardown_test_app,
)
from app.models.scenario import Scenario
from app.models.score import Score
from app.models.user import User


def test_energy_leaderboard_pagination() -> None:
    async def run_test() -> None:
        session_maker, engine = setup_test_app([User.__table__])
        try:
            now = datetime.now(timezone.utc)
            async with session_maker() as session:
                for username, energy, offset_minutes in [
                    ("alpha", 1200.0, 3),
                    ("bravo", 1000.0, 1),
                    ("charlie", 1000.0, 2),
                    ("delta", 800.0, 0),
                ]:
                    session.add(
                        User(
                            id=uuid4(),
                            username=username,
                            email=f"{username}@example.com",
                            hashed_password="hashed",
                            is_active=True,
                            energy=energy,
                            created_at=now,
                            updated_at=now + timedelta(minutes=offset_minutes),
                        )
                    )

                session.add(
                    User(
                        id=uuid4(),
                        username="inactive",
                        email="inactive@example.com",
                        hashed_password="hashed",
                        is_active=False,
                        energy=5000.0,
                        created_at=now,
                        updated_at=now + timedelta(hours=1),
                    )
                )

                await session.commit()

            async with api_client() as client:
                response = await client.get(
                    "/api/v1/energy/leaderboard",
                    params={"limit": 2, "offset": 1},
                )

            assert response.status_code == 200
            payload = response.json()
            assert [entry["username"] for entry in payload] == ["charlie", "bravo"]
            assert [entry["rank"] for entry in payload] == [2, 3]
            assert [entry["total_energy"] for entry in payload] == [1000, 1000]
        finally:
            await teardown_test_app(engine)

    asyncio.run(run_test())


def test_score_leaderboard_pagination() -> None:
    async def run_test() -> None:
        session_maker, engine = setup_test_app(
            [Scenario.__table__, User.__table__, Score.__table__]
        )
        try:
            now = datetime.now(timezone.utc)
            scenario_id = "bench_press"
            async with session_maker() as session:
                session.add(
                    Scenario(
                        id=scenario_id,
                        name="Bench Press",
                        description="Test",
                    )
                )

                users: dict[str, User] = {}
                for username in ("victor", "whiskey", "xray"):
                    user = User(
                        id=uuid4(),
                        username=username,
                        email=f"{username}@example.com",
                        hashed_password="hashed",
                        is_active=True,
                        created_at=now,
                        updated_at=now,
                    )
                    session.add(user)
                    users[username] = user

                await session.flush()

                session.add_all(
                    [
                        Score(
                            user_id=users["victor"].id,
                            scenario_id=scenario_id,
                            weight_lifted=120.0,
                            score_value=120.0,
                            created_at=now - timedelta(minutes=2),
                        ),
                        Score(
                            user_id=users["victor"].id,
                            scenario_id=scenario_id,
                            weight_lifted=140.0,
                            score_value=140.0,
                            created_at=now - timedelta(minutes=1),
                        ),
                        Score(
                            user_id=users["whiskey"].id,
                            scenario_id=scenario_id,
                            weight_lifted=160.0,
                            score_value=160.0,
                            created_at=now,
                        ),
                        Score(
                            user_id=users["xray"].id,
                            scenario_id=scenario_id,
                            weight_lifted=140.0,
                            score_value=140.0,
                            created_at=now + timedelta(minutes=1),
                        ),
                    ]
                )

                await session.commit()

            async with api_client() as client:
                response = await client.get(
                    f"/api/v1/scores/scenario/{scenario_id}/leaderboard",
                    params={"limit": 2, "offset": 1},
                )

            assert response.status_code == 200
            payload = response.json()
            assert [item["score_value"] for item in payload] == [140.0, 140.0]
            assert [item["user"]["username"] for item in payload] == [
                "xray",
                "victor",
            ]
        finally:
            await teardown_test_app(engine)

    asyncio.run(run_test())
