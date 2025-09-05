# backend/app/db/session.py

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

# This corrected version adds pooling arguments to prevent "connection was closed" errors.
engine = create_async_engine(
    str(settings.DATABASE_URL),
    # Checks if a connection is alive before using it from the pool.
    # This is the primary fix for the ConnectionDoesNotExistError.
    pool_pre_ping=True,
    # Recycles connections after 1 hour (3600s) to prevent them from
    # being closed by the database server due to idle timeouts.
    pool_recycle=3600,
    # Set echo=False for production, or True to see all SQL queries in your logs.
    echo=False,
    # This is a specific optimization recommended for Render's PostgreSQL hosting.
    connect_args={"server_settings": {"jit": "off"}}
)

# This sessionmaker is the factory for our database sessions.
async_session = sessionmaker(
    engine, expire_on_commit=False, class_=AsyncSession
)