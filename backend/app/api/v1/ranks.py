# backend/app/api/v1/ranks.py

import os

import httpx
from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.services.dots_service import DotsCalculator

router = APIRouter(prefix="/ranks", tags=["Ranks"])


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


@router.get("/rank_from_energy/{energy}", response_model=str)
async def rank_from_energy(energy: int):
  return get_rank_from_energy(energy)


async def get_user_energy(user_id: str) -> float:
  async with httpx.AsyncClient() as client:
    response = await client.get(f"{settings.BASE_URL}/api/v1/energy/latest/{user_id}")

  if response.status_code == 200:
    return float(response.json())

  raise HTTPException(status_code=response.status_code, detail="Failed to fetch energy")


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
  scenario_id: str,
  final_score: float,
  user_weight: float,
  user_gender: str = "male",
):
  async with httpx.AsyncClient() as client:
    response = await client.get(f"{settings.BASE_URL}/api/v1/scenarios/{scenario_id}/multiplier")

  if response.status_code != 200:
    raise HTTPException(status_code=response.status_code, detail="Failed to fetch scenario multiplier")

  scenario_multiplier = response.json()
  if not isinstance(scenario_multiplier, float):
    scenario_multiplier = scenario_multiplier.get("multiplier", 1)

  standards = DotsCalculator.calculate_lift_standards(
    bodyweight_kg=user_weight,
    gender=user_gender,
    lift_ratio=scenario_multiplier,
  )

  return DotsCalculator.get_current_rank_and_next_rank(
    user_lift_score=final_score,
    standards=standards,
  )


@router.get("/user/{user_id}/scenario/{scenario_id}/highscore_value")
async def get_user_high_score_value(user_id: str, scenario_id: str):
  async with httpx.AsyncClient() as client:
    response = await client.get(
      f"{settings.BASE_URL}/api/v1/scores/user/{user_id}/scenario/{scenario_id}/highscore"
    )

  if response.status_code == 200:
    score_data = response.json()
    return {"high_score": score_data.get("score_value", 0)}

  raise HTTPException(status_code=response.status_code, detail="Failed to fetch high score")
