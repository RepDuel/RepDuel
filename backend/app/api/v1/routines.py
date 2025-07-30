# backend/app/api/v1/routines.py

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.api.v1.auth import get_current_user
from app.models.user import User
from app.schemas.routine import RoutineCreate, RoutineRead, RoutineUpdate
from app.services import routine_service

router = APIRouter(prefix="/routines", tags=["Routines"])


@router.post(
    "/",
    response_model=RoutineRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a routine for the current user",
)
async def create_routine(
    payload: RoutineCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Creates a routine owned by the authenticated user.
    Ownership is encoded via `Routine.user_id`.
    """
    created = await routine_service.create_routine(db, payload, current_user.id)
    return created


@router.get(
    "/",
    response_model=List[RoutineRead],
    summary="List routines for the current user",
)
async def list_user_routines(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns the routines owned by the authenticated user (via `user_id`).
    """
    routines = await routine_service.get_user_routines(db, current_user.id)
    return routines


@router.get(
    "/{routine_id}",
    response_model=RoutineRead,
    summary="Get a routine by ID",
)
async def get_routine_by_id(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),  # kept for parity / future auth rules
):
    """
    Fetch a single routine.
    If you later want to restrict reads to owners only, add a user_id check here.
    """
    routine = await routine_service.get_routine_read(db, routine_id)
    if not routine:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Routine not found")
    return routine


@router.put(
    "/{routine_id}",
    response_model=RoutineRead,
    summary="Update a routine (owner = user_id only)",
)
async def update_routine_by_id(
    routine_id: UUID,
    updated_data: RoutineUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Updates a routine only if the authenticated user is the owner (routine.user_id).
    """
    routine_orm = await routine_service.get_routine(db, routine_id)
    if not routine_orm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Routine not found")

    if getattr(routine_orm, "user_id", None) != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to modify this routine")

    updated = await routine_service.update_routine(db, routine_orm, updated_data)
    return updated


@router.delete(
    "/{routine_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a routine (owner = user_id only)",
)
async def delete_routine_by_id(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Deletes a routine only if the authenticated user is the owner (routine.user_id).
    """
    routine_orm = await routine_service.get_routine(db, routine_id)
    if not routine_orm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Routine not found")

    if getattr(routine_orm, "user_id", None) != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to delete this routine")

    await routine_service.delete_routine(db, routine_orm)
    # 204 No Content → return nothing
