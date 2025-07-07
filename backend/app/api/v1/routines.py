# backend/app/api/v1/routines.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.api.v1.deps import get_db
from app.models.routine import Routine
from app.schemas.routine import RoutineCreate, RoutineRead, RoutineUpdate

from sqlalchemy import select
from typing import List

router = APIRouter(prefix="/routines", tags=["Routines"])


@router.post("/", response_model=RoutineRead)
async def create_routine(
    routine: RoutineCreate,
    db: AsyncSession = Depends(get_db),
):
    db_routine = Routine(**routine.dict())
    db.add(db_routine)
    await db.commit()
    await db.refresh(db_routine)
    return db_routine


@router.get("/", response_model=List[RoutineRead])
async def list_user_routines(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Routine).where(Routine.user_id == user_id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{routine_id}", response_model=RoutineRead)
async def get_routine_by_id(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    routine = await db.get(Routine, routine_id)
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")
    return routine


@router.put("/{routine_id}", response_model=RoutineRead)
async def update_routine_by_id(
    routine_id: UUID,
    updated_data: RoutineUpdate,
    db: AsyncSession = Depends(get_db),
):
    routine = await db.get(Routine, routine_id)
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    for field, value in updated_data.dict(exclude_unset=True).items():
        setattr(routine, field, value)

    await db.commit()
    await db.refresh(routine)
    return routine


@router.delete("/{routine_id}")
async def delete_routine_by_id(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    routine = await db.get(Routine, routine_id)
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    await db.delete(routine)
    await db.commit()
    return {"detail": "Routine deleted"}
