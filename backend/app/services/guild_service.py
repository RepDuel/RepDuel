from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.guild import Guild
from app.schemas.guild import GuildCreate
from app.models.user import User


async def create_guild(
    db: AsyncSession,
    guild_in: GuildCreate,
    owner: User
) -> Guild:
    guild = Guild(
        name=guild_in.name,
        icon_url=guild_in.icon_url,
        owner_id=owner.id
    )
    db.add(guild)
    await db.commit()
    await db.refresh(guild)
    return guild


async def get_user_guilds(db: AsyncSession, user_id: str) -> list[Guild]:
    result = await db.execute(
        select(Guild).where(Guild.owner_id == user_id)
    )
    return result.scalars().all()
