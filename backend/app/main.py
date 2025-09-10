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

# Explicit frontends + localhost/127.0.0.1 for dev
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
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="static"), name="static")
app.include_router(api_router, prefix="/api/v1")

@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}
