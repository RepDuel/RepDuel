import httpx
import os
from fastapi import APIRouter, Depends, HTTPException
from app.models.scenario import Scenario
from app.models.score import Score
from app.schemas.score import ScoreCreate, ScoreOut, ScoreReadWithUser
from app.services.energy_service import update_energy_if_personal_best
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi.responses import JSONResponse
from app.services.dots_service import DotsCalculator  # Importing the DotsCalculator service

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


def get_rank_icon_path(rank: str) -> str:
    # Path to the icons folder
    icon_path = 'assets/images/ranks/'

    # Match the rank to its respective icon file
    icon_files = {
        'Iron': 'iron.svg',
        'Bronze': 'bronze.svg',
        'Silver': 'silver.svg',
        'Gold': 'gold.svg',
        'Platinum': 'platinum.svg',
        'Diamond': 'diamond.svg',
        'Jade': 'jade.svg',
        'Master': 'master.svg',
        'Grandmaster': 'grandmaster.svg',
        'Nova': 'nova.svg',
        'Astra': 'astra.svg',
        'Celestial': 'celestial.svg'
    }

    # Get the file name for the rank
    icon_file = icon_files.get(rank)
    if icon_file:
        return os.path.join(icon_path, icon_file)
    else:
        raise HTTPException(status_code=400, detail=f"Invalid rank name: {rank}")


# API that returns the rank as a string based on the energy value
@router.get("/rank_from_energy/{energy}", response_model=str)
async def rank_from_energy(energy: int):
    rank = get_rank_from_energy(energy)
    return rank


async def get_user_energy(user_id: str) -> float:
    async with httpx.AsyncClient() as client:
        # Make a request to your API to get the user's latest energy
        response = await client.get(f'http://localhost:8000/api/v1/energy/latest/{user_id}')
        
        # Check if the response status is 200 (OK)
        if response.status_code == 200:
            # If the response is just a number (not a dictionary), directly return it
            return float(response.json())  # Assuming the response body is just the energy value
        # If the response is not OK, raise an HTTPException
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch energy")


# API that returns the color associated with the rank name
@router.get("/rank_color/{user_id}", response_model=str)
async def rank_color(user_id: str):
    energy = await get_user_energy(user_id)
    rank = get_rank_from_energy(energy)
    if rank not in ['Iron', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Jade', 'Master', 'Grandmaster', 'Nova', 'Astra', 'Celestial']:
        raise HTTPException(status_code=400, detail=f"Invalid rank name: {rank}")
    color = get_rank_color(rank)
    return color


# API that returns the path to the rank icon associated with the user
@router.get("/rank_icon/{user_id}", response_model=str)
async def rank_icon(user_id: str):
    energy = await get_user_energy(user_id)  # Get the user's latest energy using the external API
    rank = get_rank_from_energy(energy)  # Get the rank from the energy
    icon_path = get_rank_icon_path(rank)  # Get the icon path for the rank
    return icon_path


# New API to get rank progress based on final score, scenario id, and user info
@router.get("/get_rank_progress", response_model=dict)
async def get_rank_progress(
    scenario_id: str, 
    final_score: int, 
    user_weight: float, 
    user_gender: str = "male"
):
    """Calculate current rank and next rank threshold for a user's lift score"""
    
    # Step 1: Fetch scenario multiplier
    response = await httpx.AsyncClient().get(
        f'http://localhost:8000/api/v1/scenarios/{scenario_id}/multiplier'
    )

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch scenario multiplier")

    # Handle response as float if needed
    scenario_multiplier = response.json()

    if isinstance(scenario_multiplier, float):  # If the response is a float
        print(f"Multiplier: {scenario_multiplier}")  # Debug print to verify multiplier
    else:
        scenario_multiplier = scenario_multiplier.get("multiplier", 1)  # Default to 1 if not found
        print(f"Multiplier: {scenario_multiplier}")  # Debug print to verify multiplier

    # Step 2: Get the standards from DotsCalculator
    standards = DotsCalculator.calculate_lift_standards(
        bodyweight_kg=user_weight,
        gender=user_gender,
        lift_ratio=scenario_multiplier
    )

    # Step 3: Get rank progress based on the final score
    rank_progress = DotsCalculator.get_current_rank_and_next_rank(
        user_lift_score=final_score,
        standards=standards
    )

    return rank_progress
