# backend/app/api/v1/standards.py

from typing import Optional

from app.services.dots_service import DotsCalculator
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/standards", tags=["Standards"])


@router.get("/{bodyweight_kg}")
async def get_standards(bodyweight_kg: float, gender: Optional[str] = "male"):
    if bodyweight_kg <= 0:
        raise HTTPException(status_code=400, detail="Bodyweight must be positive")

    if gender not in ["male", "female"]:
        raise HTTPException(status_code=400, detail="Gender must be 'male' or 'female'")

    return DotsCalculator.get_lift_standards(bodyweight_kg, gender)
