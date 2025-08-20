# backend/app/services/user_service.py

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.security import hash_password, verify_password
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


async def authenticate_user(db: AsyncSession, email: str, password: str) -> User | None:
    user = await get_user_by_email(db, email)
    if user and verify_password(password, user.hashed_password):
        return user
    return None


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    result = await db.execute(select(User).where(User.email == email))
    return result.scalars().first()


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    result = await db.execute(select(User).filter(User.id == user_id))
    return result.scalars().first()


async def get_user_by_username(db: AsyncSession, username: str) -> User | None:
    result = await db.execute(select(User).filter(User.username == username))
    return result.scalars().first()


async def create_user(db: AsyncSession, user_in: UserCreate) -> User:
    user = User(
        username=user_in.username,
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        avatar_url=user_in.avatar_url,
        subscription_level="free",
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def update_user(db: AsyncSession, user: User, updates: UserUpdate) -> User:
    update_data = updates.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "password":
            setattr(user, "hashed_password", hash_password(value))
        else:
            setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return user


async def delete_user(db: AsyncSession, user_to_delete: User) -> None:
    await db.delete(user_to_delete)
    await db.commit()
    return None
