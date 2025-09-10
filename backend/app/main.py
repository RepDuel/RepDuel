# backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.api_router import api_router
from app.core.config import settings  # your Settings() already exists

app = FastAPI(
    title="RepDuel API",
    version="1.0.0",
    description="Backend for the RepDuel app",
)

# If CORS_ALLOW_ORIGINS is set, use it strictly (prod/fixed dev).
# Otherwise (dev convenience), allow any localhost/127.0.0.1 with any port—works with cookies.
origins = [str(o) for o in (getattr(settings, "CORS_ALLOW_ORIGINS", []) or [])]

if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,      # needed for refresh cookies
        allow_methods=["*"],
        allow_headers=["*"],
        max_age=86400,               # cache preflight for a day
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        max_age=86400,
    )

app.mount("/static", StaticFiles(directory="static"), name="static")
app.include_router(api_router, prefix="/api/v1")
