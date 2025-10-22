"""Utility helpers for working with user-uploaded assets."""

from __future__ import annotations

import os
import re
from typing import Optional
from urllib.parse import urlparse
from uuid import uuid4

from fastapi import HTTPException, UploadFile

from app.core.config import settings

_ABSOLUTE_URL_RE = re.compile(r"^https?://", re.IGNORECASE)

MAX_IMAGE_UPLOAD_BYTES = 10 * 1024 * 1024  # 10MB
_IMAGE_HEADER_BYTES = 8192
_MIN_CHUNK_SIZE = 64 * 1024
_ALLOWED_IMAGE_EXTENSIONS = {
    "jpeg": ".jpg",
    "png": ".png",
    "gif": ".gif",
    "bmp": ".bmp",
    "tiff": ".tiff",
    "webp": ".webp",
}


def _detect_image_format(data: bytes) -> Optional[str]:
    """Return the lowercase image format for ``data`` or ``None``.

    The implementation mirrors ``imghdr.what`` for the formats we support while
    avoiding the deprecated :mod:`imghdr` module. Only a subset of the header is
    required to identify the format, so the function gracefully handles inputs
    shorter than the expected signature length.
    """

    if len(data) >= 3 and data[:3] == b"\xff\xd8\xff":
        return "jpeg"

    if len(data) >= 8 and data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"

    if data.startswith((b"GIF87a", b"GIF89a")):
        return "gif"

    if len(data) >= 2 and data[:2] == b"BM":
        return "bmp"

    if len(data) >= 4 and data[:4] in (b"II*\x00", b"MM\x00*"):
        return "tiff"

    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"

    return None


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
        normalized_key = normalized.lstrip("/")

        def _candidates() -> list[str]:
            seen: set[str] = set()
            choices: list[str] = []

            def _add(value: Optional[str]) -> None:
                if not value:
                    return
                cleaned = str(value).rstrip("/")
                if not cleaned or cleaned in seen:
                    return
                seen.add(cleaned)
                choices.append(cleaned)

            base_url = getattr(settings, "BASE_URL", None)
            app_url = getattr(settings, "APP_URL", None)
            static_base = getattr(settings, "STATIC_PUBLIC_BASE", None)
            prefer_cdn = getattr(settings, "STATIC_PREFER_CDN", False)

            if prefer_cdn:
                _add(static_base)
                if base_url:
                    _add(f"{str(base_url).rstrip('/')}/static")
                if app_url:
                    _add(f"{str(app_url).rstrip('/')}/static")
            else:
                if base_url:
                    _add(f"{str(base_url).rstrip('/')}/static")
                if app_url:
                    _add(f"{str(app_url).rstrip('/')}/static")
                _add(static_base)

            return choices

        for base in _candidates():
            if not normalized_key:
                return base + "/"
            return f"{base}/{normalized_key}"

        return normalized if normalized_key else normalized + "/"

    if _ABSOLUTE_URL_RE.match(raw):
        return raw

    return normalized


def get_storage_path(*parts: str) -> str:
    """Return the absolute filesystem path for the given storage ``parts``.

    The path is rooted at :class:`~app.core.config.Settings.STATIC_STORAGE_DIR`,
    allowing deployments to mount a persistent volume for user uploads.
    """

    base = getattr(settings, "STATIC_STORAGE_DIR", None)
    if not base:
        raise RuntimeError("STATIC_STORAGE_DIR is not configured")
    return os.path.join(base, *parts)


def _upload_chunk_size(file: UploadFile) -> int:
    """Return a chunk size that respects the underlying spooled file limits."""

    candidates: list[int] = []
    for attr in ("spool_max_size",):
        value = getattr(file, attr, None)
        if value is not None:
            try:
                candidates.append(int(value))
            except (TypeError, ValueError):
                continue

    underlying = getattr(file, "file", None)
    if underlying is not None:
        for attr in ("max_size", "_max_size"):
            value = getattr(underlying, attr, None)
            if value is not None:
                try:
                    candidates.append(int(value))
                except (TypeError, ValueError):
                    continue

    if not candidates:
        return max(_MIN_CHUNK_SIZE, 1024 * 1024)

    # Use the largest observed limit to minimise read calls.
    return max(_MIN_CHUNK_SIZE, max(candidates))


async def save_image_upload(
    file: UploadFile,
    *,
    subdir: str,
    max_bytes: int = MAX_IMAGE_UPLOAD_BYTES,
) -> str:
    """Persist an uploaded image under ``subdir`` and return its storage key."""

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    header = await file.read(_IMAGE_HEADER_BYTES)
    if not header:
        await file.close()
        raise HTTPException(status_code=400, detail="File must be an image")

    total_bytes = len(header)
    if total_bytes > max_bytes:
        await file.close()
        raise HTTPException(status_code=413, detail="File too large")

    detected = _detect_image_format(header)
    if not detected:
        await file.close()
        raise HTTPException(status_code=400, detail="Invalid image file")

    ext = _ALLOWED_IMAGE_EXTENSIONS.get(detected)
    if not ext:
        await file.close()
        raise HTTPException(status_code=400, detail="Unsupported image format")

    directory = get_storage_path(subdir)
    os.makedirs(directory, exist_ok=True)

    filename = f"{uuid4().hex}{ext}"
    file_path = os.path.join(directory, filename)
    chunk_size = _upload_chunk_size(file)

    try:
        with open(file_path, "wb") as buffer:
            buffer.write(header)

            while True:
                chunk = await file.read(chunk_size)
                if not chunk:
                    break

                total_bytes += len(chunk)
                if total_bytes > max_bytes:
                    raise HTTPException(status_code=413, detail="File too large")

                buffer.write(chunk)
    except Exception:
        if os.path.exists(file_path):
            os.remove(file_path)
        raise
    finally:
        await file.close()

    return f"{subdir}/{filename}"
