# backend/app/api/v1/users.py

import os
import shutil
import stripe
from typing import Annotated
from uuid import uuid4

from fastapi import (
    APIRouter,
    Cookie,
    Depends,
    File,
    HTTPException,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.security import OAuth2PasswordRequestForm
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.core.config import settings
from app.core.security import create_access_token
from app.core.security import create_refresh_token

from app.models import user as models
from app.schemas import user as schemas
from app.schemas.token import Token
from app.services.user_service import (
    authenticate_user,
    create_user,
    delete_user,
    get_user_by_email,
    get_user_by_id,
    get_user_by_username,
    update_user,
)

# Initialize Stripe with your secret key from settings
stripe.api_key = settings.STRIPE_SECRET_KEY

router = APIRouter(prefix="/users", tags=["users"])

# ---------------------------
# Helpers for refresh cookie
# ---------------------------

REFRESH_COOKIE_NAME = "refresh_token"
REFRESH_COOKIE_PATH = "/api/v1/users"  # scope to /users routes

def set_refresh_cookie(response: Response, token: str) -> None:
    """Set HttpOnly Secure refresh token cookie."""
    max_age = 60 * 60 * 24 * getattr(settings, "REFRESH_TOKEN_EXPIRE_DAYS", 30)
    response.set_cookie(
        key=REFRESH_COOKIE_NAME,
        value=token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=max_age,
        path=REFRESH_COOKIE_PATH,
    )

def clear_refresh_cookie(response: Response) -> None:
    response.delete_cookie(
        key=REFRESH_COOKIE_NAME,
        path=REFRESH_COOKIE_PATH,
    )

# ---------------------------
# Registration
# ---------------------------

@router.post("/", response_model=schemas.UserRead, status_code=status.HTTP_201_CREATED)
async def register_user(
    user_in: schemas.UserCreate, db: AsyncSession = Depends(get_db)
):
    existing_user = await get_user_by_email(db, user_in.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    existing_username = await get_user_by_username(db, user_in.username)
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username is already taken",
        )

    # Create user in database first
    user = await create_user(db, user_in)

    # Create Stripe customer (best-effort)
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

# ---------------------------
# Login -> issues access + refresh
# ---------------------------

@router.post("/login", response_model=Token)
async def login_user(
    response: Response,
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: AsyncSession = Depends(get_db),
):
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    access_token = create_access_token({"sub": str(user.id)})
    refresh_token = create_refresh_token({"sub": str(user.id)})

    set_refresh_cookie(response, refresh_token)

    return {"access_token": access_token, "token_type": "bearer"}

# ---------------------------
# Silent refresh endpoint
# ---------------------------

@router.post("/refresh", response_model=Token)
async def refresh_access_token(
    response: Response,
    refresh_cookie: str | None = Cookie(default=None, alias=REFRESH_COOKIE_NAME),
):
    """
    Exchange a valid refresh token (HttpOnly cookie) for a new access token.
    Rotates the refresh token by setting a new cookie.
    """
    if not refresh_cookie:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing refresh token",
        )

    try:
        payload = jwt.decode(
            refresh_cookie,
            settings.JWT_REFRESH_SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        token_type = payload.get("typ")
        if token_type and token_type != "refresh":
            raise JWTError("Invalid token type")

        user_id = payload.get("sub")
        if not user_id:
            raise JWTError("Invalid token payload")
    except JWTError:
        clear_refresh_cookie(response)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    new_access = create_access_token({"sub": user_id})
    new_refresh = create_refresh_token({"sub": user_id})
    set_refresh_cookie(response, new_refresh)

    return {"access_token": new_access, "token_type": "bearer"}

# ---------------------------
# Logout -> clears refresh cookie
# ---------------------------

@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout_user(response: Response):
    clear_refresh_cookie(response)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

# ---------------------------
# Me / Update / Read helpers
# ---------------------------

@router.get("/me", response_model=schemas.UserRead)
async def read_current_user(current_user: models.User = Depends(get_current_user)):
    return current_user

@router.patch("/me", response_model=schemas.UserRead)
async def update_current_user(
    updates: schemas.UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if updates.username and await get_user_by_username(db, updates.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username is already taken",
        )
    if updates.email and await get_user_by_email(db, updates.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    return await update_user(db, current_user, updates)

@router.get("/{user_id}", response_model=schemas.UserRead)
async def read_user_by_id(user_id: str, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found",
        )
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

# ---------------------------
# Avatar upload
# ---------------------------

@router.patch("/me/avatar", response_model=schemas.UserRead)
async def upload_avatar(
    request: Request,
    file: UploadFile = File(..., alias="avatar"),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    ext = os.path.splitext(file.filename)[1]
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

# ---------------------------
# Delete user
# ---------------------------

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_current_user(
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    await delete_user(db, current_user)
    return None
