# backend/app/api/v1/standards.py

from fastapi import APIRouter, HTTPException
from typing import Optional
from app.services.dots_service import DotsCalculator

router = APIRouter(prefix="/standards", tags=["DOTs Standards"])

@router.get("/{bodyweight_kg}")
async def get_standards(
    bodyweight_kg: float,
    gender: Optional[str] = "male"
):
    if bodyweight_kg <= 0:
        raise HTTPException(status_code=400, detail="Bodyweight must be positive")
    
    if gender not in ["male", "female"]:
        raise HTTPException(status_code=400, detail="Gender must be 'male' or 'female'")
    
    return DotsCalculator.get_lift_standards(bodyweight_kg, gender)

@router.get("/rank/{dots_score}")
async def get_rank_info(dots_score: float):
    return DotsCalculator.get_rank(dots_score)