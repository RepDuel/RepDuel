# backend/app/db/session.py

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

engine = create_async_engine(str(settings.DATABASE_URL), future=True, echo=False)
async_session = sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
