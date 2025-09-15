# backend/app/api/v1/users.py

import os
import shutil
from typing import Annotated
from uuid import uuid4

import stripe
from fastapi import APIRouter, Depends, File, HTTPException, Request, Response, UploadFile, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, decode_refresh_token
from app.models import user as models
from app.schemas import user as schemas
from app.schemas.token import Token
from sqlalchemy import select, delete
from app.models.hidden_routine import HiddenRoutine
from app.services.user_service import (
    authenticate_user,
    create_user,
    delete_user,
    get_user_by_email,
    get_user_by_id,
    get_user_by_username,
    update_user,
)

stripe.api_key = settings.STRIPE_SECRET_KEY

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/", response_model=schemas.UserRead, status_code=status.HTTP_201_CREATED)
async def register_user(user_in: schemas.UserCreate, db: AsyncSession = Depends(get_db)):
    existing_user = await get_user_by_email(db, user_in.email)
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
    existing_username = await get_user_by_username(db, user_in.username)
    if existing_username:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username is already taken")

    user = await create_user(db, user_in)

    try:
        stripe_customer = stripe.Customer.create(
            email=user.email,
            name=user.username,
            metadata={"user_id": str(user.id), "username": user.username},
        )
        user.stripe_customer_id = stripe_customer.id
        db.add(user)
        await db.commit()
        await db.refresh(user)
    except stripe.error.StripeError as e:
        print(f"Failed to create Stripe customer for user {user.id}: {str(e)}")
    except Exception as e:
        print(f"Unexpected error creating Stripe customer for user {user.id}: {str(e)}")

    return user


@router.post("/login", response_model=Token)
async def login_user(
    response: Response,
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: AsyncSession = Depends(get_db),
):
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    access_token = create_access_token({"sub": str(user.id)})
    refresh_token = create_refresh_token({"sub": str(user.id)})

    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=getattr(settings, "COOKIE_SECURE", True),
        samesite=getattr(settings, "COOKIE_SAMESITE", "None"),
        path="/api/v1/users/refresh",
    )

    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/refresh", response_model=Token)
async def refresh_token_endpoint(
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    cookie = request.cookies.get("refresh_token")
    if not cookie:
        raise HTTPException(status_code=401, detail="Missing refresh cookie")

    payload = decode_refresh_token(cookie)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    new_access = create_access_token({"sub": str(user.id)})
    new_refresh = create_refresh_token({"sub": str(user.id)})

    response.set_cookie(
        key="refresh_token",
        value=new_refresh,
        httponly=True,
        secure=getattr(settings, "COOKIE_SECURE", True),
        samesite=getattr(settings, "COOKIE_SAMESITE", "None"),
        path="/api/v1/users/refresh",
    )

    return {"access_token": new_access, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserRead)
async def read_current_user(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=schemas.UserRead)
async def update_current_user(
    updates: schemas.UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Uniqueness checks (skip if unchanged)
    if updates.username and updates.username != current_user.username:
        if await get_user_by_username(db, updates.username):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username is already taken")
    if updates.email and updates.email != current_user.email:
        if await get_user_by_email(db, updates.email):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    return await update_user(db, current_user, updates)


@router.patch("/me/unit", response_model=schemas.UserRead)
async def update_unit_preference(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Atomically update preferred_unit (kg|lbs), adjust weight_multiplier,
    and recompute energy/rank against the corresponding rounded threshold pack.
    """
    new_unit = payload.get("preferred_unit")
    if new_unit not in ("kg", "lbs"):
        raise HTTPException(
            status_code=422,
            detail="preferred_unit must be 'kg' or 'lbs'",
        )

    if new_unit == current_user.preferred_unit:
        # No change; just return current profile
        return current_user

    # Apply update
    current_user.preferred_unit = new_unit
    current_user.weight_multiplier = 1.0 if new_unit == "kg" else 2.20462

    # Recompute energy/rank using the dual-rounded thresholds policy
    from app.services.energy_service import recompute_for_user  # type: ignore

    energy, rank = await recompute_for_user(current_user, new_unit, db)
    current_user.energy = energy
    current_user.rank = rank

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user



@router.get("/{user_id}", response_model=schemas.UserRead)
async def read_user_by_id(user_id: str, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"User with ID {user_id} not found")
    return user


@router.get("/username/{username}", response_model=schemas.UserRead)
async def get_user_uuid_by_username(username: str, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_username(db, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with username '{username}' not found",
        )
    return user


@router.patch("/me/avatar", response_model=schemas.UserRead)
async def upload_avatar(
    request: Request,
    file: UploadFile = File(..., alias="avatar"),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    ext = os.path.splitext(file.filename)[1] if file.filename else ""
    filename = f"{uuid4().hex}{ext}"
    avatar_dir = os.path.join("static", "avatars")
    os.makedirs(avatar_dir, exist_ok=True)

    file_path = os.path.join(avatar_dir, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    public_url = str(request.base_url) + f"static/avatars/{filename}"
    current_user.avatar_url = public_url

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    return current_user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_current_user(
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    await delete_user(db, current_user)
    return None


# --- Hidden routines (per-user server-side persistence) ---

@router.get("/me/hidden-routines", response_model=list[str])
async def get_hidden_routines(
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    result = await db.execute(select(HiddenRoutine.routine_id).where(HiddenRoutine.user_id == current_user.id))
    rows = result.scalars().all()
    # Return as string UUIDs
    return [str(r) for r in rows]


@router.post("/me/hidden-routines/{routine_id}", status_code=status.HTTP_204_NO_CONTENT)
async def hide_routine(
    routine_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    try:
        entry = HiddenRoutine(user_id=current_user.id, routine_id=routine_id)
        db.add(entry)
        await db.commit()
    except Exception:
        # Ignore duplicates or casting issues silently for idempotency
        await db.rollback()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/me/hidden-routines/{routine_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unhide_routine(
    routine_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    await db.execute(
        delete(HiddenRoutine).where(
            HiddenRoutine.user_id == current_user.id,
            HiddenRoutine.routine_id == routine_id,
        )
    )
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
