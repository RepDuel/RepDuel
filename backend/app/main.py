# backend/app/main.py

import os

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from app.core.config import settings

from app.api.v1.api_router import api_router

app = FastAPI(
    title="RepDuel API",
    version="1.0.0",
    description="Backend for the RepDuel app",
)

try:
    _origins = [str(u).rstrip('/') for u in (settings.FRONTEND_ORIGINS or [])]
except Exception:
    _origins = []

if getattr(settings, "APP_URL", None):
    _origins.append(str(settings.APP_URL).rstrip('/'))

# Dedupe while preserving order
ALLOWED_ORIGINS = list(dict.fromkeys(_origins))

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

static_cors_config = dict(cors_config)
static_cors_config["allow_methods"] = ["GET", "HEAD", "OPTIONS"]

static_app = StaticFiles(directory="static")
app.mount("/static", CORSMiddleware(static_app, **static_cors_config), name="static")

app.include_router(api_router, prefix="/api/v1")
from app.api.aasa import router as aasa_router
app.include_router(aasa_router, include_in_schema=False)


@app.get("/", tags=["health"])
def root():
    return {"status": "ok", "service": "repduel-backend"}


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}


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
