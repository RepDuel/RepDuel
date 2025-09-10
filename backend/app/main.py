# backend/app/main.py

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.api_router import api_router

app = FastAPI(
    title="RepDuel API",
    version="1.0.0",
    description="Backend for the RepDuel app",
)

# Explicit dev/staging origin on Render
ALLOWED_ORIGINS = [
    "https://repduel-web-dev.onrender.com",
]

# Allow:
# - https://repduel.com and any subdomain (e.g., https://www.repduel.com, https://staging.repduel.com)
# - http/https localhost and 127.0.0.1 on any port
ALLOWED_ORIGIN_REGEX = r"^https:\/\/([a-z0-9-]+\.)*repduel\.com$|^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$"

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,       # specific non-repduel origin(s)
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,  # repduel.com + localhost
    allow_credentials=True,              # needed for cookies / withCredentials
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}

app.include_router(api_router, prefix="/api/v1")
