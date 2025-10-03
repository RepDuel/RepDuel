"""Utility helpers for working with user-uploaded assets."""

from __future__ import annotations

import re
from typing import Optional
from urllib.parse import urlparse

from app.core.config import settings

_ABSOLUTE_URL_RE = re.compile(r"^https?://", re.IGNORECASE)


def _allowed_storage_netlocs() -> set[str]:
    allowed: set[str] = {
        "127.0.0.1",
        "127.0.0.1:8000",
        "localhost",
        "localhost:8000",
        "0.0.0.0",
        "0.0.0.0:8000",
    }
    for attr in ("STATIC_PUBLIC_BASE", "BASE_URL", "APP_URL"):
        raw = getattr(settings, attr, None)
        if not raw:
            continue
        parsed = urlparse(str(raw))
        if parsed.netloc:
            allowed.add(parsed.netloc.lower())
    return allowed


def _static_path_prefixes() -> list[str]:
    prefixes: list[str] = []
    base = getattr(settings, "STATIC_PUBLIC_BASE", None)
    if base:
        parsed = urlparse(str(base))
        base_path = parsed.path.lstrip("/")
        if base_path:
            prefixes.append(base_path.rstrip("/") + "/")
    prefixes.append("static/")
    return prefixes


def normalize_storage_key(value: Optional[str]) -> Optional[str]:
    """Normalize a potentially absolute ``value`` into a storage key.

    The function strips known public prefixes (``STATIC_PUBLIC_BASE`` and the
    legacy ``/static`` path) and returns the remaining key. If the value is
    empty or points to an unknown external host the function returns ``None``.
    """

    if value is None:
        return None

    raw = value.strip()
    if not raw:
        return None

    raw = raw.replace("\\", "/")
    raw = raw.split("?")[0].split("#")[0]

    path = raw
    if _ABSOLUTE_URL_RE.match(raw):
        parsed = urlparse(raw)
        if parsed.netloc:
            allowed_hosts = _allowed_storage_netlocs()
            if allowed_hosts and parsed.netloc.lower() not in allowed_hosts:
                return None
        path = parsed.path or ""

    path = path.lstrip("/")
    if not path:
        return None

    for prefix in _static_path_prefixes():
        if prefix and path.startswith(prefix):
            path = path[len(prefix) :]
            break

    return path or None


def build_public_url(key: Optional[str]) -> Optional[str]:
    """Return the absolute public URL for the given storage ``key``.

    ``key`` should be the path of the object in the backing store (e.g. S3).
    For backwards compatibility, if ``key`` is already an absolute URL outside
    of the configured storage origin, it is returned unchanged.
    """

    if key is None:
        return None

    raw = key.strip()
    if not raw:
        return None

    normalized = normalize_storage_key(raw)
    if normalized:
        base = getattr(settings, "STATIC_PUBLIC_BASE", None)
        if not base:
            return normalized
        base_str = str(base).rstrip("/")
        normalized_key = normalized.lstrip("/")
        return f"{base_str}/{normalized_key}" if normalized_key else base_str + "/"

    if _ABSOLUTE_URL_RE.match(raw):
        return raw

    return normalized
