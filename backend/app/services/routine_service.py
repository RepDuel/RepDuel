# backend/app/services/routine_service.py

from typing import List, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import joinedload

from app.models.routine import Routine
from app.schemas.routine import RoutineCreate, RoutineUpdate


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
    await db.flush()  # So the routine gets an ID

    if routine_in.scenario_ids:
        from app.models.scenario import Scenario
        scenarios = await db.execute(
            select(Scenario).where(Scenario.id.in_(routine_in.scenario_ids))
        )
        routine.scenarios = scenarios.scalars().all()

    db.add(routine)
    await db.commit()
    await db.refresh(routine)
    return routine


async def update_routine(
    db: AsyncSession, routine: Routine, routine_in: RoutineUpdate
) -> Routine:
    routine.name = routine_in.name

    if routine_in.scenario_ids is not None:
        from app.models.scenario import Scenario
        scenarios = await db.execute(
            select(Scenario).where(Scenario.id.in_(routine_in.scenario_ids))
        )
        routine.scenarios = scenarios.scalars().all()

    await db.commit()
    await db.refresh(routine)
    return routine


async def delete_routine(db: AsyncSession, routine: Routine) -> None:
    await db.delete(routine)
    await db.commit()
