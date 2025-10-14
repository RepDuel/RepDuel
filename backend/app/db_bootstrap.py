"""Database bootstrap helpers for local/remote DSN selection."""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Optional
from urllib.parse import urlparse

import asyncpg

_DEFAULT_BOOTSTRAP_TIMEOUT = 10.0

_LOGGER = logging.getLogger(__name__)
_INITIALIZED = False
_SELECTED_DSN: Optional[str] = None


def _strict_mode() -> bool:
    return os.getenv("REPDUEL_STRICT_DB_BOOTSTRAP", "0") == "1"


def _bootstrap_timeout() -> float:
    raw_value = os.getenv("REPDUEL_DB_BOOTSTRAP_TIMEOUT")
    if raw_value is None:
        return _DEFAULT_BOOTSTRAP_TIMEOUT

    try:
        parsed = float(raw_value)
    except (TypeError, ValueError):  # pragma: no cover - defensive path
        _LOGGER.warning(
            "Invalid REPDUEL_DB_BOOTSTRAP_TIMEOUT value '%s'; using default %.1fs.",
            raw_value,
            _DEFAULT_BOOTSTRAP_TIMEOUT,
        )
        return _DEFAULT_BOOTSTRAP_TIMEOUT

    # Guard against zero/negative values that would lead to immediate failures.
    if parsed <= 0:
        _LOGGER.warning(
            "REPDUEL_DB_BOOTSTRAP_TIMEOUT must be positive; using default %.1fs.",
            _DEFAULT_BOOTSTRAP_TIMEOUT,
        )
        return _DEFAULT_BOOTSTRAP_TIMEOUT

    return parsed


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


def _normalize_for_asyncpg(dsn: str) -> str:
    """
    asyncpg expects schemes 'postgresql://' or 'postgres://'.
    Strip SQLAlchemy driver suffixes like '+asyncpg'.
    """
    if not dsn:
        return dsn
    dsn = dsn.replace("postgresql+asyncpg://", "postgresql://")
    dsn = dsn.replace("postgres+asyncpg://", "postgres://")
    return dsn


async def _attempt_connect(dsn: str) -> None:
    # Normalize so asyncpg accepts SQLAlchemy-style DSNs.
    dsn_for_asyncpg = _normalize_for_asyncpg(dsn)
    timeout = _bootstrap_timeout()
    conn = await asyncpg.connect(dsn_for_asyncpg, timeout=timeout)
    await conn.close()


def _pick_first(*candidates: Optional[str]) -> Optional[str]:
    for candidate in candidates:
        value = _sanitize(candidate)
        if value:
            return value
    return None


async def pick_dsn() -> str:
    # Prefer explicit "internal/local" first, then public/remote.
    local = _pick_first(
        os.getenv("DATABASE_URL_INTERNAL"),
        os.getenv("DATABASE_URL_LOCAL"),
    )
    remote = _pick_first(
        os.getenv("DATABASE_URL"),
        os.getenv("DATABASE_URL_REMOTE"),
    )

    # Backfill if only one side provided.
    if not local:
        local = _pick_first(
            os.getenv("DATABASE_URL_LOCAL"),
            os.getenv("DATABASE_URL"),
        )

    if not remote:
        remote = _pick_first(
            os.getenv("DATABASE_URL_REMOTE"),
            os.getenv("DATABASE_URL_INTERNAL"),
        )

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
    os.environ["DATABASE_URL"] = chosen  # Keep a single canonical env var for SQLAlchemy.
    global _SELECTED_DSN
    _SELECTED_DSN = chosen
    return chosen


def init_sync() -> str:
    """
    Synchronous bootstrap helper for scripts/tests.
    Do NOT call from within a running asyncio loop (e.g. inside FastAPI app).
    """
    global _INITIALIZED
    if _INITIALIZED:
        assert _SELECTED_DSN is not None
        return _SELECTED_DSN

    try:
        loop = asyncio.get_running_loop()
        if loop.is_running():
            raise RuntimeError(
                "init_sync() cannot be called from a running event loop. "
                "Use 'await init_env()' during app startup instead."
            )
    except RuntimeError:
        # No running loop; safe to use asyncio.run
        pass

    chosen = asyncio.run(init_env())
    _INITIALIZED = True
    _LOGGER.info("Database DSN selected: %s", _describe_dsn(chosen))
    return chosen


def get_selected_dsn() -> Optional[str]:
    return _SELECTED_DSN
