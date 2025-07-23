from fastapi import APIRouter, Depends, HTTPException
from app.models.scenario import Scenario
from app.models.score import Score
from app.schemas.score import ScoreCreate, ScoreOut, ScoreReadWithUser
from app.services.energy_service import update_energy_if_personal_best
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/ranks", tags=["Ranks"])

# Existing rank determination logic (adjusted to match the structure you provided)
def get_rank_from_energy(energy: int) -> str:
    if energy >= 1200:
        return 'Celestial'
    if energy >= 1100:
        return 'Astra'
    if energy >= 1000:
        return 'Nova'
    if energy >= 900:
        return 'Grandmaster'
    if energy >= 800:
        return 'Master'
    if energy >= 700:
        return 'Jade'
    if energy >= 600:
        return 'Diamond'
    if energy >= 500:
        return 'Platinum'
    if energy >= 400:
        return 'Gold'
    if energy >= 300:
        return 'Silver'
    if energy >= 200:
        return 'Bronze'
    return 'Iron'


def get_rank_color(rank: str) -> str:
    rank_colors = {
        'Iron': '#808080',
        'Bronze': '#cd7f32',
        'Silver': '#c0c0c0',
        'Gold': '#efbf04',
        'Platinum': '#00ced1',
        'Diamond': '#b9f2ff',
        'Jade': '#62f40c',
        'Master': '#ff00ff',
        'Grandmaster': '#ffde21',
        'Nova': '#a45ee5',
        'Astra': '#ff4040',
        'Celestial': '#00ffff'
    }
    return rank_colors.get(rank, '#FFFFFF')  # Default to white if not found


# API that returns the rank as a string based on the energy value
@router.get("/rank_from_energy/{energy}", response_model=str)
async def rank_from_energy(energy: int):
    rank = get_rank_from_energy(energy)
    return rank


# API that returns the color associated with the rank name
@router.get("/rank_color/{rank}", response_model=str)
async def rank_color(rank: str):
    color = get_rank_color(rank)
    if color == '#FFFFFF':  # Color is white if the rank isn't valid
        raise HTTPException(status_code=400, detail="Invalid rank name")
    return color
