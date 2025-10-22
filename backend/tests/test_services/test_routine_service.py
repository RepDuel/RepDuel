# backend/tests/test_services/test_routine_service.py

import asyncio
from contextlib import contextmanager
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import event
from sqlalchemy.engine import Engine

from tests.test_support.app_setup import setup_test_app, teardown_test_app
from app.models.hidden_routine import HiddenRoutine
from app.models.routine import Routine
from app.models.routine_scenario import RoutineScenario
from app.models.scenario import Scenario
from app.models.user import User
from app.services import routine_service


@contextmanager
def query_counter(engine: Engine):
    stats = {"count": 0}

    def before_cursor_execute(*_args, **_kwargs):
        stats["count"] += 1

    event.listen(engine, "before_cursor_execute", before_cursor_execute)
    try:
        yield stats
    finally:
        event.remove(engine, "before_cursor_execute", before_cursor_execute)


def test_get_user_routines_loads_in_batches() -> None:
    async def run_test() -> None:
        session_maker, engine = setup_test_app(
            [
                User.__table__,
                Scenario.__table__,
                Routine.__table__,
                RoutineScenario.__table__,
                HiddenRoutine.__table__,
            ]
        )
        try:
            now = datetime.now(timezone.utc)
            user_id = uuid4()
            async with session_maker() as session:
                session.add(
                    User(
                        id=user_id,
                        username="loader",
                        email="loader@example.com",
                        hashed_password="hashed",
                        is_active=True,
                        created_at=now,
                        updated_at=now,
                    )
                )

                scenarios = []
                for index in range(3):
                    scenario = Scenario(
                        id=f"scenario-{index}",
                        name=f"Scenario {index}",
                        description="Test scenario",
                    )
                    session.add(scenario)
                    scenarios.append(scenario)

                await session.flush()

                for routine_index in range(5):
                    routine = Routine(
                        id=uuid4(),
                        name=f"Routine {routine_index}",
                        user_id=user_id,
                        is_share_template=False,
                        created_at=now,
                    )
                    session.add(routine)
                    await session.flush()

                    for scenario in scenarios:
                        session.add(
                            RoutineScenario(
                                routine_id=routine.id,
                                scenario_id=scenario.id,
                                sets=3,
                                reps=8,
                            )
                        )

                await session.commit()

            with query_counter(engine) as stats:
                async with session_maker() as session:
                    routines = await routine_service.get_user_routines(session, user_id)

            assert len(routines) == 5
            assert stats["count"] <= 3
        finally:
            await teardown_test_app(engine)

    asyncio.run(run_test())
