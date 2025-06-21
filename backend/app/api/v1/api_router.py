from fastapi import APIRouter

from app.api.v1.users import router as users_router
from app.api.v1.guilds import router as guilds_router
from app.api.v1.channels import router as channels_router
from app.api.v1.messages import router as messages_router
from app.api.v1.websockets import router as websockets_router

api_router = APIRouter()

api_router.include_router(users_router)
api_router.include_router(guilds_router)
api_router.include_router(channels_router)
api_router.include_router(websockets_router)
api_router.include_router(messages_router)

