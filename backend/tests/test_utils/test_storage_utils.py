"""Tests for storage helper utilities."""

import asyncio
import base64
import os
from io import BytesIO

import pytest
from fastapi import HTTPException
from starlette.datastructures import Headers, UploadFile

os.environ.setdefault("APP_URL", "http://testserver")
os.environ.setdefault("BASE_URL", "http://testserver")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")
os.environ.setdefault("JWT_SECRET_KEY", "secret")
os.environ.setdefault("REVENUECAT_WEBHOOK_AUTH_TOKEN", "token")
os.environ.setdefault("STRIPE_SECRET_KEY", "sk_test")
os.environ.setdefault("STRIPE_WEBHOOK_SECRET", "whsec_test")

from app.core.config import settings
from app.utils.storage import (
    MAX_IMAGE_UPLOAD_BYTES,
    build_public_url,
    get_storage_path,
    normalize_storage_key,
    save_image_upload,
)

_PNG_BYTES = base64.b64decode(
    b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/lh0XWwAAAABJRU5ErkJggg=="
)


def _make_upload(data: bytes, *, filename: str = "avatar.png") -> UploadFile:
    return UploadFile(
        filename=filename,
        file=BytesIO(data),
        headers=Headers({"content-type": "image/png"}),
    )


def test_normalize_storage_key_strips_static_prefix(monkeypatch):
    monkeypatch.setattr(settings, "STATIC_PUBLIC_BASE", "https://cdn.repduel.com")
    result = normalize_storage_key("static/avatars/foo.png")
    assert result == "avatars/foo.png"


def test_normalize_storage_key_handles_absolute_local_url(monkeypatch):
    monkeypatch.setattr(settings, "STATIC_PUBLIC_BASE", "https://cdn.repduel.com")
    url = "http://127.0.0.1:8000/static/routine-images/bar.jpg"
    result = normalize_storage_key(url)
    assert result == "routine-images/bar.jpg"


def test_build_public_url_rewrites_legacy_local_urls(monkeypatch):
    monkeypatch.setattr(settings, "STATIC_PUBLIC_BASE", "https://cdn.repduel.com")
    monkeypatch.setattr(settings, "STATIC_PREFER_CDN", False)
    legacy = "http://127.0.0.1:8000/static/routine-images/example.png"
    result = build_public_url(legacy)
    assert result == "http://testserver/static/routine-images/example.png"


def test_build_public_url_uses_cdn_when_preferred(monkeypatch):
    monkeypatch.setattr(settings, "STATIC_PUBLIC_BASE", "https://cdn.repduel.com")
    monkeypatch.setattr(settings, "STATIC_PREFER_CDN", True)
    result = build_public_url("routine-images/example.png")
    assert result == "https://cdn.repduel.com/routine-images/example.png"


def test_build_public_url_passes_through_external_host(monkeypatch):
    monkeypatch.setattr(settings, "STATIC_PUBLIC_BASE", "https://cdn.repduel.com")
    external = "https://images.example.com/photo.png"
    result = build_public_url(external)
    assert result == external


def test_get_storage_path_uses_static_storage_dir(monkeypatch, tmp_path):
    base = tmp_path / "uploads"
    monkeypatch.setattr(settings, "STATIC_STORAGE_DIR", str(base))
    result = get_storage_path("avatars", "example.png")
    assert result == os.path.join(str(base), "avatars", "example.png")


def test_save_image_upload_persists_file(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "STATIC_STORAGE_DIR", str(tmp_path))
    upload = _make_upload(_PNG_BYTES)

    storage_key = asyncio.run(save_image_upload(upload, subdir="avatars"))

    saved = tmp_path / storage_key
    assert saved.exists()
    assert saved.read_bytes() == _PNG_BYTES


def test_save_image_upload_rejects_large_files(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "STATIC_STORAGE_DIR", str(tmp_path))
    too_large = _PNG_BYTES + b"\x00" * (MAX_IMAGE_UPLOAD_BYTES + 1 - len(_PNG_BYTES))
    upload = _make_upload(too_large, filename="big.png")

    with pytest.raises(HTTPException) as exc:
        asyncio.run(save_image_upload(upload, subdir="avatars"))

    assert exc.value.status_code == 413
    avatars_dir = tmp_path / "avatars"
    assert avatars_dir.exists()
    assert list(avatars_dir.iterdir()) == []


def test_save_image_upload_rejects_invalid_signature(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "STATIC_STORAGE_DIR", str(tmp_path))
    upload = _make_upload(b"not an image")

    with pytest.raises(HTTPException) as exc:
        asyncio.run(save_image_upload(upload, subdir="avatars"))

    assert exc.value.status_code == 400
    assert "avatars" not in {p.name for p in tmp_path.iterdir()}
