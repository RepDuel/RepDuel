# backend/app/api/v1/api_router.py

from fastapi import APIRouter

from app.api.v1.energy import router as energy_router
from app.api.v1.guilds import router as guilds_router
from app.api.v1.levels import router as levels_router
from app.api.v1.payments import router as payments_router
from app.api.v1.ranks import router as ranks_router
from app.api.v1.routine_submission import router as routine_submission_router
from app.api.v1.routines import router as routines_router
from app.api.v1.scenario import router as scenario_router
from app.api.v1.score import router as score_router
from app.api.v1.social import router as social_router
from app.api.v1.standards import router as standards_router
from app.api.v1.users import router as users_router
from app.api.v1.webhooks import router as webhooks_router

api_router = APIRouter()

api_router.include_router(payments_router)
api_router.include_router(users_router)
api_router.include_router(guilds_router)
api_router.include_router(scenario_router)
api_router.include_router(score_router)
api_router.include_router(standards_router)
api_router.include_router(routines_router)
api_router.include_router(energy_router)
api_router.include_router(routine_submission_router)
api_router.include_router(ranks_router)
api_router.include_router(webhooks_router)
api_router.include_router(levels_router)
api_router.include_router(social_router)
