# backend/alembic/env.py
import asyncio
import os
import sys
from logging.config import fileConfig
from pathlib import Path

from sqlalchemy import create_engine, pool
from sqlalchemy.engine.url import make_url
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import context

# Ensure app imports resolve
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.core.config import settings
from app.db.base import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# ---- URL resolution (async for app, sync for Alembic) ----
raw_url = os.getenv("DATABASE_URL_SYNC") or os.getenv("DATABASE_URL") or str(settings.DATABASE_URL)
url = str(raw_url)

def as_sync(u: str) -> str:
    return u.replace("+asyncpg", "")

def as_async(u: str) -> str:
    # only upgrade if it looks like a plain pg URL
    return u if "+asyncpg" in u else u.replace("postgresql://", "postgresql+asyncpg://", 1)

SYNC_URL = as_sync(url)     # Alembic uses this
ASYNC_URL = as_async(url)   # app / optional async path

# ---- Offline ----
def run_migrations_offline() -> None:
    context.configure(
        url=SYNC_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

# ---- Online ----
def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

async def run_migrations_online() -> None:
    # Use sync engine for migrations for maximum compatibility
    engine = create_engine(SYNC_URL, poolclass=pool.NullPool)
    try:
        with engine.connect() as connection:
            do_run_migrations(connection)
    finally:
        engine.dispose()

if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
