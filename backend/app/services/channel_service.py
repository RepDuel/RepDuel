# backend/app/services/channel_service.py

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.channel import Channel
from app.schemas.channel import ChannelCreate


async def create_channel(db: AsyncSession, channel_in: ChannelCreate) -> Channel:
    channel = Channel(name=channel_in.name, guild_id=channel_in.guild_id)
    db.add(channel)
    await db.commit()
    await db.refresh(channel)
    return channel


async def get_channels_by_guild(db: AsyncSession, guild_id: UUID) -> list[Channel]:
    result = await db.execute(select(Channel).where(Channel.guild_id == guild_id))
    return result.scalars().all()
