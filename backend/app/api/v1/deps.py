# backend/app/api/v1/deps.py

from typing import AsyncGenerator

from app.db.session import async_session
from sqlalchemy.ext.asyncio import AsyncSession


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session
