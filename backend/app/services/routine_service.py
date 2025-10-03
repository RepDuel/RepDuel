# backend/app/services/routine_service.py

import secrets
import string
from typing import List, Optional
from uuid import UUID, uuid4

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.models.hidden_routine import HiddenRoutine
from app.models.routine import Routine
from app.models.routine_scenario import RoutineScenario
from app.models.routine_share_snapshot import RoutineShareSnapshot
from app.schemas.routine import (
    RoutineCreate,
    RoutineRead,
    RoutineUpdate,
    ScenarioSet,
)
from app.schemas.routine_share import RoutineShareRead
from app.utils.storage import normalize_storage_key


async def get_routine(db: AsyncSession, routine_id: UUID) -> Optional[Routine]:
    result = await db.execute(select(Routine).where(Routine.id == routine_id))
    return result.scalar_one_or_none()


async def get_routine_read(db: AsyncSession, routine_id: UUID) -> Optional[RoutineRead]:
    routine = await get_routine(db, routine_id)
    if not routine:
        return None

    scenario_result = await db.execute(
        select(RoutineScenario)
        .options(selectinload(RoutineScenario.scenario))
        .where(RoutineScenario.routine_id == routine.id)
    )
    scenario_links = scenario_result.scalars().all()

    scenarios = [
        ScenarioSet(
            scenario_id=link.scenario_id,
            name=link.scenario.name if link.scenario else "Unnamed",
            sets=link.sets,
            reps=link.reps,
        )
        for link in scenario_links
    ]

    return RoutineRead(
        id=routine.id,
        name=routine.name,
        image_url=normalize_storage_key(routine.image_url) or routine.image_url,
        user_id=routine.user_id,
        created_at=routine.created_at,
        scenarios=scenarios,
    )


async def get_user_routines(
    db: AsyncSession, user_id: Optional[UUID]
) -> List[RoutineRead]:
    stmt = select(Routine).where(Routine.is_share_template.is_(False))
    if user_id:
        hidden_subquery = select(HiddenRoutine.routine_id).where(
            HiddenRoutine.user_id == user_id
        )
        stmt = stmt.where((Routine.user_id == user_id) | (Routine.user_id.is_(None)))
        stmt = stmt.where(~Routine.id.in_(hidden_subquery))

    result = await db.execute(stmt)
    routines = result.scalars().all()

    routine_reads = []
    for routine in routines:
        scenario_result = await db.execute(
            select(RoutineScenario)
            .options(selectinload(RoutineScenario.scenario))
            .where(RoutineScenario.routine_id == routine.id)
        )
        scenario_links = scenario_result.scalars().all()

        scenarios = [
            ScenarioSet(
                scenario_id=link.scenario_id,
                name=link.scenario.name if link.scenario else "Unnamed",
                sets=link.sets,
                reps=link.reps,
            )
            for link in scenario_links
        ]

        routine_reads.append(
            RoutineRead(
                id=routine.id,
                name=routine.name,
                image_url=normalize_storage_key(routine.image_url) or routine.image_url,
                user_id=routine.user_id,
                created_at=routine.created_at,
                scenarios=scenarios,
            )
        )

    return routine_reads


async def create_routine(
    db: AsyncSession, routine_in: RoutineCreate, user_id: Optional[UUID] = None
) -> RoutineRead:
    routine = Routine(
        id=uuid4(),
        name=routine_in.name,
        image_url=routine_in.image_url,
        user_id=user_id,
        is_share_template=False,
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
            RoutineScenario.__table__.delete().where(
                RoutineScenario.routine_id == routine.id
            )
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
        RoutineScenario.__table__.delete().where(
            RoutineScenario.routine_id == routine.id
        )
    )
    await db.delete(routine)
    await db.commit()


_CODE_ALPHABET = string.ascii_uppercase + string.digits
_CODE_LENGTH = 8


def _normalize_share_code(code: str) -> str:
    return code.strip().upper()


def _scenario_to_payload(item: ScenarioSet) -> dict:
    return {
        "scenario_id": item.scenario_id,
        "name": item.name,
        "sets": int(item.sets),
        "reps": int(item.reps),
    }


def _scenario_from_payload(raw: dict) -> ScenarioSet:
    return ScenarioSet(
        scenario_id=str(raw.get("scenario_id")),
        name=str(raw.get("name") or raw.get("scenario_id") or "Exercise"),
        sets=int(raw.get("sets") or 0),
        reps=int(raw.get("reps") or 0),
    )


async def _generate_unique_share_code(db: AsyncSession) -> str:
    while True:
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))
        existing = await db.execute(
            select(RoutineShareSnapshot).where(RoutineShareSnapshot.code == code)
        )
        if existing.scalar_one_or_none() is None:
            return code


def _share_snapshot_to_schema(snapshot: RoutineShareSnapshot) -> RoutineShareRead:
    scenarios_raw = snapshot.scenarios or []
    scenarios = [_scenario_from_payload(item) for item in scenarios_raw]
    return RoutineShareRead(
        code=snapshot.code,
        name=snapshot.name,
        image_url=snapshot.image_url,
        scenarios=scenarios,
        created_at=snapshot.created_at,
    )


async def create_routine_share(
    db: AsyncSession,
    routine: Routine,
    created_by_user_id: Optional[UUID],
) -> RoutineShareRead:
    routine_data = await get_routine_read(db, routine.id)
    if not routine_data:
        raise ValueError("Routine not found")

    code = await _generate_unique_share_code(db)
    snapshot = RoutineShareSnapshot(
        code=code,
        name=routine_data.name,
        image_url=normalize_storage_key(routine_data.image_url) or routine_data.image_url,
        scenarios=[_scenario_to_payload(item) for item in routine_data.scenarios],
        source_routine_id=routine.id,
        created_by_user_id=created_by_user_id,
    )
    db.add(snapshot)
    await db.commit()
    await db.refresh(snapshot)
    return _share_snapshot_to_schema(snapshot)


async def get_routine_share_snapshot(
    db: AsyncSession, share_code: str
) -> Optional[RoutineShareRead]:
    normalized = _normalize_share_code(share_code)
    result = await db.execute(
        select(RoutineShareSnapshot).where(RoutineShareSnapshot.code == normalized)
    )
    snapshot = result.scalar_one_or_none()
    if not snapshot:
        return None
    return _share_snapshot_to_schema(snapshot)


async def import_shared_routine(
    db: AsyncSession, share: RoutineShareRead, user_id: UUID
) -> RoutineRead:
    payload = RoutineCreate(
        name=share.name,
        image_url=share.image_url,
        scenarios=[_scenario_from_payload(item.model_dump()) for item in share.scenarios],
    )
    return await create_routine(db, payload, user_id)
