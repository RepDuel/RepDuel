# backend/app/api/v1/channels.py

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.user import User
from app.schemas.channel import ChannelCreate, ChannelRead
from app.services.channel_service import create_channel, get_channels_by_guild

router = APIRouter(prefix="/channels", tags=["channels"])


@router.post("/", response_model=ChannelRead, status_code=status.HTTP_201_CREATED)
async def create_new_channel(
    channel_in: ChannelCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await create_channel(db, channel_in)


@router.get("/guild/{guild_id}", response_model=list[ChannelRead])
async def get_guild_channels(
    guild_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_channels_by_guild(db, guild_id)
