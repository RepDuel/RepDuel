import os

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.models.scenario import Scenario
from app.models.score import Score
from app.schemas.score import ScoreCreate, ScoreOut, ScoreReadWithUser
from app.services.dots_service import DotsCalculator
from app.services.energy_service import update_energy_if_personal_best

router = APIRouter(prefix="/ranks", tags=["Ranks"])


# ------------ RANK LOGIC ------------


def get_rank_from_energy(energy: int) -> str:
    if energy >= 1200:
        return "Celestial"
    if energy >= 1100:
        return "Astra"
    if energy >= 1000:
        return "Nova"
    if energy >= 900:
        return "Grandmaster"
    if energy >= 800:
        return "Master"
    if energy >= 700:
        return "Jade"
    if energy >= 600:
        return "Diamond"
    if energy >= 500:
        return "Platinum"
    if energy >= 400:
        return "Gold"
    if energy >= 300:
        return "Silver"
    if energy >= 200:
        return "Bronze"
    return "Iron"


def get_rank_color(rank: str) -> str:
    rank_colors = {
        "Iron": "#808080",
        "Bronze": "#cd7f32",
        "Silver": "#c0c0c0",
        "Gold": "#efbf04",
        "Platinum": "#00ced1",
        "Diamond": "#b9f2ff",
        "Jade": "#62f40c",
        "Master": "#ff00ff",
        "Grandmaster": "#ffde21",
        "Nova": "#a45ee5",
        "Astra": "#ff4040",
        "Celestial": "#00ffff",
    }
    return rank_colors.get(rank, "#FFFFFF")


def get_rank_icon_path(rank: str) -> str:
    icon_path = "assets/images/ranks/"
    icon_files = {
        "Iron": "iron.svg",
        "Bronze": "bronze.svg",
        "Silver": "silver.svg",
        "Gold": "gold.svg",
        "Platinum": "platinum.svg",
        "Diamond": "diamond.svg",
        "Jade": "jade.svg",
        "Master": "master.svg",
        "Grandmaster": "grandmaster.svg",
        "Nova": "nova.svg",
        "Astra": "astra.svg",
        "Celestial": "celestial.svg",
    }
    icon_file = icon_files.get(rank)
    if icon_file:
        return os.path.join(icon_path, icon_file)
    raise HTTPException(status_code=400, detail=f"Invalid rank name: {rank}")


# ------------ ROUTES ------------


@router.get("/rank_from_energy/{energy}", response_model=str)
async def rank_from_energy(energy: int):
    return get_rank_from_energy(energy)


async def get_user_energy(user_id: str) -> float:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{settings.BASE_URL}/api/v1/energy/latest/{user_id}"
        )

    if response.status_code == 200:
        return float(response.json())

    raise HTTPException(
        status_code=response.status_code, detail="Failed to fetch energy"
    )


@router.get("/rank_color/{user_id}", response_model=str)
async def rank_color(user_id: str):
    energy = await get_user_energy(user_id)
    rank = get_rank_from_energy(energy)

    if rank not in {
        "Iron",
        "Bronze",
        "Silver",
        "Gold",
        "Platinum",
        "Diamond",
        "Jade",
        "Master",
        "Grandmaster",
        "Nova",
        "Astra",
        "Celestial",
    }:
        raise HTTPException(status_code=400, detail=f"Invalid rank name: {rank}")

    return get_rank_color(rank)


@router.get("/rank_icon/{user_id}", response_model=str)
async def rank_icon(user_id: str):
    energy = await get_user_energy(user_id)
    rank = get_rank_from_energy(energy)
    return get_rank_icon_path(rank)


@router.get("/get_rank_progress", response_model=dict)
async def get_rank_progress(
    scenario_id: str, final_score: int, user_weight: float, user_gender: str = "male"
):
    # Step 1: Fetch scenario multiplier
    async with httpx.AsyncClient() as client:
        print(
            f"DEBUG: Fetching multiplier from {settings.BASE_URL}/api/v1/scenarios/{scenario_id}/multiplier"
        )
        response = await client.get(
            f"{settings.BASE_URL}/api/v1/scenarios/{scenario_id}/multiplier"
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail="Failed to fetch scenario multiplier",
        )

    scenario_multiplier = response.json()
    if not isinstance(scenario_multiplier, float):
        scenario_multiplier = scenario_multiplier.get("multiplier", 1)

    # Step 2: Get lift standards
    standards = DotsCalculator.calculate_lift_standards(
        bodyweight_kg=user_weight, gender=user_gender, lift_ratio=scenario_multiplier
    )

    # Step 3: Determine rank
    return DotsCalculator.get_current_rank_and_next_rank(
        user_lift_score=final_score, standards=standards
    )
