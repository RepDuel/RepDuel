# backend/app/main.py

import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

from app.api.v1.api_router import api_router

app = FastAPI(
    title="RepDuel API",
    version="1.0.0",
    description="Backend for the RepDuel app",
)

# ======================================
# CORS (unchanged)
# ======================================
ALLOWED_ORIGINS = [
    "https://repduel-web-dev.onrender.com",
    "https://repduel.com",
    "https://www.repduel.com",
]
ALLOWED_ORIGIN_REGEX = r"^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$"

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_credentials=True,  # required for cookies
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# ======================================
# Paths: where the Flutter web build lives
# Set FRONTEND_WEB_DIR if your path differs
# e.g., FRONTEND_WEB_DIR=/workspace/frontend/build/web
# ======================================
WEB_DIR = os.getenv(
    "FRONTEND_WEB_DIR",
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "build", "web"),
)
INDEX_FILE = os.path.join(WEB_DIR, "index.html")

# ======================================
# Static file mounts (hashed asset dirs get long cache)
# ======================================
def _mount_if_exists(route: str, folder: str):
    directory = os.path.join(WEB_DIR, folder)
    if os.path.isdir(directory):
        app.mount(route, StaticFiles(directory=directory, html=False, check_dir=False), name=folder)

# Typical Flutter web folders
_mount_if_exists("/assets", "assets")
_mount_if_exists("/canvaskit", "canvaskit")
_mount_if_exists("/icons", "icons")

# Your app's own static directory (uploads, etc.)
app.mount("/static", StaticFiles(directory="static"), name="static")

# ======================================
# API routes
# ======================================
app.include_router(api_router, prefix="/api/v1")

# ======================================
# Health endpoints (Render pings "/")
# ======================================
@app.get("/", tags=["health"])
def root():
    return {"status": "ok", "service": "repduel-backend"}

@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}

# ======================================
# Caching policy:
# - index.html (and other top-level .js/.css) -> no-cache
# - hashed asset folders (/assets, /canvaskit, /icons) -> 1y immutable
# This ensures *new deploys* are visible immediately while keeping assets fast.
# ======================================
@app.middleware("http")
async def cache_headers(request: Request, call_next):
    response = await call_next(request)
    p = request.url.path

    # Long cache for hashed assets
    if p.startswith(("/assets/", "/canvaskit/", "/icons/")):
        response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        return response

    # Be conservative for top-level files that Flutter doesn't always hash
    if p in ("/", "/index.html") or p.endswith((".html", ".js", ".css", ".json", ".wasm", ".svg", ".png")):
        # We only want the SPA shell and top-level resources to be revalidated
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        return response

    return response

# ======================================
# Optional: retire any legacy Flutter service worker to avoid stale builds.
# Set KEEP_SW=1 if you intentionally want offline/PWA behavior.
# ======================================
KEEP_SW = os.getenv("KEEP_SW", "0") == "1"

@app.get("/flutter_service_worker.js")
def maybe_remove_sw():
    if not KEEP_SW:
        # 410 Gone strongly nudges browsers to uninstall the old SW
        return Response(status_code=410)
    # If you *do* keep a SW, serve it with no-cache so updates propagate
    sw_path = os.path.join(WEB_DIR, "flutter_service_worker.js")
    if os.path.exists(sw_path):
        return FileResponse(sw_path, headers={"Cache-Control": "no-cache, must-revalidate"})
    return Response(status_code=404)

# main.dart.js is sometimes un-hashed; force no-cache
@app.get("/main.dart.js")
def main_js():
    path = os.path.join(WEB_DIR, "main.dart.js")
    if os.path.exists(path):
        return FileResponse(path, headers={"Cache-Control": "no-cache, no-store, must-revalidate"})
    return Response(status_code=404)

# ======================================
# SPA fallback:
# - Serves index.html for deep links like /routines
# - Registered LAST so /api/* and other routes still work
# ======================================
if os.path.exists(INDEX_FILE):
    @app.get("/{full_path:path}", include_in_schema=False)
    def spa(full_path: str):
        # Don't hijack API or mounted routes
        if full_path.startswith(("api/", "static/", "assets/", "canvaskit/", "icons/")):
            return Response(status_code=404)
        return FileResponse(INDEX_FILE, headers={"Cache-Control": "no-cache, must-revalidate"})
