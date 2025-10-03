"""Tests for storage helper utilities."""

import os

os.environ.setdefault("APP_URL", "http://testserver")
os.environ.setdefault("BASE_URL", "http://testserver")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")
os.environ.setdefault("JWT_SECRET_KEY", "secret")
os.environ.setdefault("REVENUECAT_WEBHOOK_AUTH_TOKEN", "token")
os.environ.setdefault("STRIPE_SECRET_KEY", "sk_test")
os.environ.setdefault("STRIPE_WEBHOOK_SECRET", "whsec_test")

from app.core.config import settings
from app.utils.storage import build_public_url, normalize_storage_key


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
    legacy = "http://127.0.0.1:8000/static/routine-images/example.png"
    result = build_public_url(legacy)
    assert result == "https://cdn.repduel.com/routine-images/example.png"


def test_build_public_url_passes_through_external_host(monkeypatch):
    monkeypatch.setattr(settings, "STATIC_PUBLIC_BASE", "https://cdn.repduel.com")
    external = "https://images.example.com/photo.png"
    result = build_public_url(external)
    assert result == external
