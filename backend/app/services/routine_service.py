# backend/app/services/routine_service.py

from typing import List, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.routine import Routine
from app.models.routine_scenario import RoutineScenario
from app.schemas.routine import RoutineCreate, RoutineUpdate, ScenarioSet, RoutineRead


async def get_routine(db: AsyncSession, routine_id: UUID) -> Optional[Routine]:
    result = await db.execute(select(Routine).where(Routine.id == routine_id))
    return result.scalar_one_or_none()


async def get_routine_read(db: AsyncSession, routine_id: UUID) -> Optional[RoutineRead]:
    routine = await get_routine(db, routine_id)
    if not routine:
        return None

    scenario_result = await db.execute(
        select(RoutineScenario).where(RoutineScenario.routine_id == routine.id)
    )
    scenario_links = scenario_result.scalars().all()

    scenarios = [
        ScenarioSet(
            scenario_id=link.scenario_id,
            sets=link.sets,
            reps=link.reps
        ) for link in scenario_links
    ]

    return RoutineRead(
        id=routine.id,
        name=routine.name,
        image_url=routine.image_url,
        user_id=routine.user_id,
        created_at=routine.created_at,
        scenarios=scenarios
    )


async def get_user_routines(db: AsyncSession, user_id: Optional[UUID]) -> List[RoutineRead]:
    stmt = select(Routine)
    if user_id:
        stmt = stmt.where((Routine.user_id == user_id) | (Routine.user_id.is_(None)))

    result = await db.execute(stmt)
    routines = result.scalars().all()

    routine_reads = []
    for routine in routines:
        scenario_result = await db.execute(
            select(RoutineScenario).where(RoutineScenario.routine_id == routine.id)
        )
        scenario_links = scenario_result.scalars().all()

        scenarios = [
            ScenarioSet(
                scenario_id=link.scenario_id,
                sets=link.sets,
                reps=link.reps
            ) for link in scenario_links
        ]

        routine_reads.append(
            RoutineRead(
                id=routine.id,
                name=routine.name,
                image_url=routine.image_url,
                user_id=routine.user_id,
                created_at=routine.created_at,
                scenarios=scenarios
            )
        )

    return routine_reads


async def create_routine(db: AsyncSession, routine_in: RoutineCreate, user_id: Optional[UUID] = None) -> RoutineRead:
    routine = Routine(
        name=routine_in.name,
        image_url=routine_in.image_url,
        user_id=user_id
    )
    db.add(routine)
    await db.flush()

    for item in routine_in.scenarios:
        assoc = RoutineScenario(
            routine_id=routine.id,
            scenario_id=item.scenario_id,
            sets=item.sets,
            reps=item.reps,
        )
        db.add(assoc)

    await db.commit()
    return await get_routine_read(db, routine.id)


async def update_routine(
    db: AsyncSession, routine: Routine, routine_in: RoutineUpdate
) -> RoutineRead:
    routine.name = routine_in.name
    routine.image_url = routine_in.image_url

    if routine_in.scenarios is not None:
        await db.execute(
            RoutineScenario.__table__.delete().where(RoutineScenario.routine_id == routine.id)
        )

        for item in routine_in.scenarios:
            assoc = RoutineScenario(
                routine_id=routine.id,
                scenario_id=item.scenario_id,
                sets=item.sets,
                reps=item.reps,
            )
            db.add(assoc)

    await db.commit()
    return await get_routine_read(db, routine.id)


async def delete_routine(db: AsyncSession, routine: Routine) -> None:
    await db.execute(
        RoutineScenario.__table__.delete().where(RoutineScenario.routine_id == routine.id)
    )
    await db.delete(routine)
    await db.commit()
