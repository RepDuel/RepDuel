from typing import Annotated
import os
import shutil
from uuid import uuid4

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Request,
    status,
    UploadFile,
    File,
)
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.core.security import create_access_token
from app.models import user as models
from app.schemas import user as schemas
from app.schemas.token import Token
from app.services.user_service import (
    authenticate_user,
    create_user,
    get_user_by_email,
    update_user,
    get_user_by_id,
    get_user_by_username,
)

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/", response_model=schemas.UserRead, status_code=status.HTTP_201_CREATED)
async def register_user(user_in: schemas.UserCreate, db: AsyncSession = Depends(get_db)):
    existing_user = await get_user_by_email(db, user_in.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    return await create_user(db, user_in)


@router.post("/login", response_model=Token)
async def login_user(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: AsyncSession = Depends(get_db),
):
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserRead)
async def read_current_user(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=schemas.UserRead)
async def update_current_user(
    updates: schemas.UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
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


@router.patch("/me/avatar", response_model=schemas.UserRead)
async def upload_avatar(
    request: Request,
    file: UploadFile = File(..., alias="avatar"),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Validate image
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # Generate unique filename and create directory
    ext = os.path.splitext(file.filename)[1]
    filename = f"{uuid4().hex}{ext}"
    avatar_dir = os.path.join("static", "avatars")
    os.makedirs(avatar_dir, exist_ok=True)

    # Save image
    file_path = os.path.join(avatar_dir, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Generate full public URL
    public_url = str(request.base_url) + f"static/avatars/{filename}"
    current_user.avatar_url = public_url

    # Save user
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    print(f"[✅] Uploaded avatar: {file.filename} as {filename} ({file.content_type})")

    return current_user
