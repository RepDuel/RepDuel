from typing import List, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import joinedload

from app.models.routine import Routine
from app.models.routine_scenario import RoutineScenario
from app.schemas.routine import RoutineCreate, RoutineUpdate, ScenarioSet


async def get_routine(db: AsyncSession, routine_id: UUID) -> Optional[Routine]:
    result = await db.execute(
        select(Routine).where(Routine.id == routine_id).options(joinedload(Routine.scenarios))
    )
    return result.scalars().first()


async def get_user_routines(db: AsyncSession, user_id: UUID) -> List[Routine]:
    result = await db.execute(
        select(Routine).where(Routine.user_id == user_id).options(joinedload(Routine.scenarios))
    )
    return result.scalars().all()


async def create_routine(db: AsyncSession, user_id: UUID, routine_in: RoutineCreate) -> Routine:
    routine = Routine(name=routine_in.name, user_id=user_id)
    db.add(routine)
    await db.flush()  # Assign ID before adding associations

    for item in routine_in.scenarios:
        db.add(RoutineScenario(
            routine_id=routine.id,
            scenario_id=item.scenario_id,
            sets=item.sets,
            reps=item.reps,
        ))

    await db.commit()
    await db.refresh(routine)
    return routine


async def update_routine(
    db: AsyncSession, routine: Routine, routine_in: RoutineUpdate
) -> Routine:
    routine.name = routine_in.name

    if routine_in.scenarios is not None:
        # Remove old scenario associations
        await db.execute(
            RoutineScenario.__table__.delete().where(RoutineScenario.routine_id == routine.id)
        )

        # Add new scenario associations
        for item in routine_in.scenarios:
            db.add(RoutineScenario(
                routine_id=routine.id,
                scenario_id=item.scenario_id,
                sets=item.sets,
                reps=item.reps,
            ))

    await db.commit()
    await db.refresh(routine)
    return routine


async def delete_routine(db: AsyncSession, routine: Routine) -> None:
    await db.execute(
        RoutineScenario.__table__.delete().where(RoutineScenario.routine_id == routine.id)
    )
    await db.delete(routine)
    await db.commit()
