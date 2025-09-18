# backend/app/db/session.py

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.db.base import Base

engine = create_async_engine(
    str(settings.DATABASE_URL),
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False,
    connect_args={"server_settings": {"jit": "off"}},
)

async_session = sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
