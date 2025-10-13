"""Database bootstrap helpers for local/remote DSN selection."""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Optional
from urllib.parse import urlparse

import asyncpg

_LOGGER = logging.getLogger(__name__)
_INITIALIZED = False
_SELECTED_DSN: Optional[str] = None


def _strict_mode() -> bool:
    return os.getenv("REPDUEL_STRICT_DB_BOOTSTRAP", "0") == "1"


def _sanitize(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    return value.strip() or None


def _describe_dsn(dsn: str) -> str:
    try:
        parsed = urlparse(dsn)
        host = parsed.hostname or "?"
        port = parsed.port or "?"
        database = parsed.path.lstrip("/") or "?"
        return f"{host}:{port}/{database}"
    except Exception:
        return "<custom>"


async def _attempt_connect(dsn: str) -> None:
    conn = await asyncpg.connect(dsn, timeout=2.5)
    await conn.close()


async def pick_dsn() -> str:
    local = _sanitize(os.getenv("DATABASE_URL_LOCAL") or os.getenv("DATABASE_URL"))
    remote = _sanitize(os.getenv("DATABASE_URL_REMOTE"))

    last_error: Optional[Exception] = None
    strict = _strict_mode()

    if local:
        try:
            await _attempt_connect(local)
            return local
        except Exception as exc:  # pragma: no cover - diagnostic path
            _LOGGER.warning("Local database DSN failed bootstrap check: %s", exc)
            last_error = exc

    if remote:
        try:
            await _attempt_connect(remote)
            if local and last_error:
                _LOGGER.info("Falling back to remote database DSN after local failure.")
            return remote
        except Exception as exc:  # pragma: no cover - diagnostic path
            _LOGGER.warning("Remote database DSN failed bootstrap check: %s", exc)
            last_error = exc

    if strict and last_error:
        raise last_error

    if local:
        _LOGGER.warning("Proceeding with local database DSN without bootstrap verification.")
        return local

    if remote:
        _LOGGER.warning("Proceeding with remote database DSN without bootstrap verification.")
        return remote

    raise RuntimeError("No database DSN provided in environment variables.")


async def init_env() -> str:
    chosen = await pick_dsn()
    os.environ["DATABASE_URL"] = chosen
    global _SELECTED_DSN
    _SELECTED_DSN = chosen
    return chosen


def init_sync() -> str:
    global _INITIALIZED
    if _INITIALIZED:
        assert _SELECTED_DSN is not None
        return _SELECTED_DSN

    chosen = asyncio.run(init_env())
    _INITIALIZED = True
    _LOGGER.info("Database DSN selected: %s", _describe_dsn(chosen))
    return chosen


def get_selected_dsn() -> Optional[str]:
    return _SELECTED_DSN
