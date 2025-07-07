from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.api.v1.deps import get_db
from app.schemas.routine import RoutineCreate, RoutineRead, RoutineUpdate
from app.services import routine_service

from typing import List

router = APIRouter(prefix="/routines", tags=["Routines"])


@router.post("/", response_model=RoutineRead)
async def create_routine(
    routine: RoutineCreate,
    user_id: UUID = Query(...),
    db: AsyncSession = Depends(get_db),
):
    return await routine_service.create_routine(db, user_id, routine)


@router.get("/", response_model=List[RoutineRead])
async def list_user_routines(
    user_id: UUID = Query(...),
    db: AsyncSession = Depends(get_db),
):
    return await routine_service.get_user_routines(db, user_id)


@router.get("/{routine_id}", response_model=RoutineRead)
async def get_routine_by_id(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    routine = await routine_service.get_routine(db, routine_id)
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")
    return routine


@router.put("/{routine_id}", response_model=RoutineRead)
async def update_routine_by_id(
    routine_id: UUID,
    updated_data: RoutineUpdate,
    db: AsyncSession = Depends(get_db),
):
    routine = await routine_service.get_routine(db, routine_id)
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    return await routine_service.update_routine(db, routine, updated_data)


@router.delete("/{routine_id}")
async def delete_routine_by_id(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    routine = await routine_service.get_routine(db, routine_id)
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    await routine_service.delete_routine(db, routine)
    return {"detail": "Routine deleted"}
