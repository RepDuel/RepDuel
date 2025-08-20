# backend/app/api/v1/guilds.py

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.user import User
from app.schemas.guild import GuildCreate, GuildRead
from app.services.guild_service import create_guild, get_user_guilds

router = APIRouter(prefix="/guilds", tags=["guilds"])


@router.post("/", response_model=GuildRead, status_code=status.HTTP_201_CREATED)
async def create_user_guild(
    guild_in: GuildCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await create_guild(db, guild_in, current_user)


@router.get("/", response_model=list[GuildRead])
async def get_my_guilds(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_user_guilds(db, current_user.id)
