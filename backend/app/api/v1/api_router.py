from fastapi import APIRouter
from app.api.v1.users import router as users_router
from app.api.v1.guilds import router as guilds_router

api_router = APIRouter()

api_router.include_router(users_router)
api_router.include_router(guilds_router)
