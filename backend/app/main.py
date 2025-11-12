# backend/app/main.py

import os
from contextlib import asynccontextmanager
from urllib.parse import urlparse

import asyncpg
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
from sqlalchemy import text
from sqlalchemy.exc import OperationalError
from fastapi.staticfiles import StaticFiles

# ✅ Initialize DB env at startup (not at import time)
from app.db_bootstrap import init_env

from app.core.celery_app import celery_app
from app.core.config import settings
from app.api.v1.api_router import api_router
from app.db.session import async_session

_fastapi_kwargs = dict(
    title="RepDuel API",
    version="1.0.0",
    description="Backend for the RepDuel app",
)


@asynccontextmanager
async def _lifespan(app: FastAPI):  # pragma: no cover - exercised via app startup
    # Run async initialization when the app starts (avoids asyncio.run() inside a running loop)
    await init_env()
    yield


_base_url = getattr(settings, "BASE_URL", "").strip()
if _base_url:
    _fastapi_kwargs["servers"] = [{"url": _base_url.rstrip("/")}]

app = FastAPI(lifespan=_lifespan, **_fastapi_kwargs)

def _origin(url: str | None) -> str | None:
    if not url:
        return None
    try:
        parsed = urlparse(str(url).strip())
    except ValueError:
        return None
    if not parsed.scheme or not parsed.netloc:
        return None
    return f"{parsed.scheme}://{parsed.netloc}".rstrip("/")


_origins: list[str] = []

for candidate in getattr(settings, "FRONTEND_ORIGINS", []) or []:
    origin = _origin(str(candidate))
    if origin:
        _origins.append(origin)

for candidate in (
    _origin(getattr(settings, "APP_URL", None)),
    _origin(getattr(settings, "STATIC_PUBLIC_BASE", None)),
):
    if candidate:
        _origins.append(candidate)

_DEFAULT_DEV_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5000",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

_origins.extend(_DEFAULT_DEV_ORIGINS)

# Production origin
_origins.append("https://www.repduel.com")

# Dedupe while preserving order
ALLOWED_ORIGINS = [origin for origin in dict.fromkeys(_origins) if origin]

# Keep localhost regex for dev convenience
ALLOWED_ORIGIN_REGEX = r"^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$"

cors_config = dict(
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

app.add_middleware(CORSMiddleware, **cors_config)

WEB_DIR = os.getenv(
    "FRONTEND_WEB_DIR",
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "build", "web"),
)
INDEX_FILE = os.path.join(WEB_DIR, "index.html")


def _mount_if_exists(route: str, folder: str):
    directory = os.path.join(WEB_DIR, folder)
    if os.path.isdir(directory):
        app.mount(route, StaticFiles(directory=directory, html=False, check_dir=False), name=folder)


_mount_if_exists("/assets", "assets")
_mount_if_exists("/canvaskit", "canvaskit")
_mount_if_exists("/icons", "icons")

STATIC_DIR = getattr(settings, "STATIC_STORAGE_DIR", None)
if not STATIC_DIR:
    raise RuntimeError("STATIC_STORAGE_DIR must be configured")
os.makedirs(STATIC_DIR, exist_ok=True)
static_app = StaticFiles(directory=STATIC_DIR)
# CORS is handled by the main app middleware, no need to wrap static files
app.mount("/static", static_app, name="static")

app.include_router(api_router, prefix="/api/v1")
from app.api.aasa import router as aasa_router
app.include_router(aasa_router, include_in_schema=False)


def _db_unavailable_response() -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={
            "detail": "Unable to connect to the database. Ensure the Postgres service is running."
        },
    )


@app.exception_handler(ConnectionRefusedError)
async def _handle_connection_refused(request: Request, exc: ConnectionRefusedError):
    return _db_unavailable_response()


@app.exception_handler(asyncpg.exceptions.PostgresError)
async def _handle_asyncpg_errors(request: Request, exc: asyncpg.exceptions.PostgresError):
    # Surface connection issues with a consistent, actionable response.
    if isinstance(exc, asyncpg.exceptions.InterfaceError):
        return _db_unavailable_response()
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "A database error occurred."},
    )


@app.exception_handler(OperationalError)
async def _handle_operational_error(request: Request, exc: OperationalError):
    if isinstance(getattr(exc, "orig", None), ConnectionRefusedError):
        return _db_unavailable_response()
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "A database error occurred."},
    )


@app.get("/", tags=["health"])
def root():
    return {"status": "ok", "service": "repduel-backend"}


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}


@app.get("/health/db", tags=["health"])
async def health_db():
    async with async_session() as session:
        await session.execute(text("SELECT 1"))
    return {"status": "ok", "database": "reachable"}


def _queue_depth(snapshot: dict[str, list] | None) -> int:
    if not snapshot:
        return 0
    return sum(len(tasks or []) for tasks in snapshot.values())


@app.get("/health/queue", tags=["health"])
def health_queue():
    if getattr(settings, "CELERY_TASK_ALWAYS_EAGER", False):
        return {"status": "eager", "queue_depth": 0, "workers": []}
    try:
        inspector = celery_app.control.inspect(timeout=1)
    except Exception as exc:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "error", "detail": "unable to reach celery control", "error": str(exc)},
        )
    if inspector is None:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "unavailable", "queue_depth": None, "workers": []},
        )
    try:
        stats = inspector.stats() or {}
    except Exception:
        stats = {}
    try:
        active = inspector.active() or {}
        reserved = inspector.reserved() or {}
        scheduled = inspector.scheduled() or {}
    except Exception:
        active = reserved = scheduled = {}
    depth = _queue_depth(active) + _queue_depth(reserved) + _queue_depth(scheduled)
    status_label = "ok" if stats else "degraded"
    return {
        "status": status_label,
        "queue_depth": depth,
        "workers": list(stats.keys()),
    }


@app.middleware("http")
async def cache_headers(request: Request, call_next):
    response = await call_next(request)
    p = request.url.path

    if p.startswith(("/assets/", "/canvaskit/", "/icons/")):
        response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        return response

    if p in ("/", "/index.html") or p.endswith((".html", ".js", ".css", ".json", ".wasm", ".svg", ".png")):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        return response

    return response


KEEP_SW = os.getenv("KEEP_SW", "0") == "1"


@app.get("/flutter_service_worker.js")
def maybe_remove_sw():
    if not KEEP_SW:
        return Response(status_code=410)
    sw_path = os.path.join(WEB_DIR, "flutter_service_worker.js")
    if os.path.exists(sw_path):
        return FileResponse(sw_path, headers={"Cache-Control": "no-cache, must-revalidate"})
    return Response(status_code=404)


@app.get("/main.dart.js")
def main_js():
    path = os.path.join(WEB_DIR, "main.dart.js")
    if os.path.exists(path):
        return FileResponse(path, headers={"Cache-Control": "no-cache, no-store, must-revalidate"})
    return Response(status_code=404)


if os.path.exists(INDEX_FILE):
    @app.get("/{full_path:path}", include_in_schema=False)
    def spa(full_path: str):
        if full_path.startswith(("api/", "static/", "assets/", "canvaskit/", "icons/")):
            return Response(status_code=404)
        return FileResponse(INDEX_FILE, headers={"Cache-Control": "no-cache, must-revalidate"})

