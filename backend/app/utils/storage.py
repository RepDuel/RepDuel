"""Utility helpers for working with user-uploaded assets."""

from __future__ import annotations

import re
from typing import Optional

from app.core.config import settings

_ABSOLUTE_URL_RE = re.compile(r"^https?://", re.IGNORECASE)


def build_public_url(key: Optional[str]) -> Optional[str]:
    """Return the absolute public URL for the given storage ``key``.

    ``key`` should be the path of the object in the backing store (e.g. S3).
    For backwards compatibility, if ``key`` is already an absolute URL, it is
    returned unchanged.
    """

    if not key:
        return None

    key = key.strip()
    if not key:
        return None

    if _ABSOLUTE_URL_RE.match(key):
        return key

    base = getattr(settings, "STATIC_PUBLIC_BASE", None)
    if not base:
        return key

    base_str = str(base).rstrip("/")
    normalized_key = key.lstrip("/")
    return f"{base_str}/{normalized_key}" if normalized_key else base_str + "/"
