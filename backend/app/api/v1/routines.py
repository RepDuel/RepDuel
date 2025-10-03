# backend/app/api/v1/routines.py

from typing import List
import os
import shutil
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.routine import Routine
from app.models.user import User
from app.schemas.routine import RoutineCreate, RoutineRead, RoutineUpdate
from app.schemas.routine_share import RoutineImportRequest, RoutineShareRead
from app.services import routine_service
from app.utils.storage import build_public_url

router = APIRouter(prefix="/routines", tags=["Routines"])


@router.post(
    "/images",
    status_code=status.HTTP_201_CREATED,
    summary="Upload an image for a routine",
)
async def upload_routine_image(
    request: Request,
    file: UploadFile = File(..., alias="image"),
    _current_user: User = Depends(get_current_user),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    ext = os.path.splitext(file.filename or "")[1]
    filename = f"{uuid4().hex}{ext}"
    image_dir = os.path.join("static", "routine-images")
    os.makedirs(image_dir, exist_ok=True)

    file_path = os.path.join(image_dir, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    storage_key = f"routine-images/{filename}"
    public_url = build_public_url(storage_key)
    if not public_url:
        public_url = str(request.base_url).rstrip("/") + f"/static/{storage_key}"
    return {"image_url": public_url, "image_key": storage_key}


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
    if current_user.subscription_level == "free":
        result = await db.execute(
            select(func.count()).select_from(Routine).where(Routine.user_id == current_user.id)
        )
        routine_count = result.scalar()
        if routine_count >= 3:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Free users are limited to 3 custom routines. Upgrade to create more.",
            )

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
    current_user: User = Depends(get_current_user),
):
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
    routine_orm = await routine_service.get_routine(db, routine_id)
    if not routine_orm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Routine not found")

    if getattr(routine_orm, "user_id", None) != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to modify this routine"
        )

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
    routine_orm = await routine_service.get_routine(db, routine_id)
    if not routine_orm:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Routine not found")

    if getattr(routine_orm, "user_id", None) != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to delete this routine"
        )

    await routine_service.delete_routine(db, routine_orm)


@router.post(
    "/{routine_id}/share",
    response_model=RoutineShareRead,
    summary="Create a share code for a routine",
)
async def create_routine_share_code(
    routine_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    routine = await routine_service.get_routine(db, routine_id)
    if not routine:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Routine not found")

    if routine.user_id is not None and routine.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to share this routine",
        )

    share = await routine_service.create_routine_share(db, routine, current_user.id)
    return share


@router.get(
    "/shared/{share_code}",
    response_model=RoutineShareRead,
    summary="Fetch a shared routine snapshot by code",
)
async def get_shared_routine_snapshot(
    share_code: str,
    db: AsyncSession = Depends(get_db),
):
    share = await routine_service.get_routine_share_snapshot(db, share_code)
    if not share:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Share code not found")
    return share


@router.post(
    "/import",
    response_model=RoutineRead,
    status_code=status.HTTP_201_CREATED,
    summary="Import a routine by share code",
)
async def import_routine_by_share_code(
    payload: RoutineImportRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    share = await routine_service.get_routine_share_snapshot(db, payload.share_code)
    if not share:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Share code not found")

    created = await routine_service.import_shared_routine(db, share, current_user.id)
    return created
