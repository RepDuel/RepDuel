# backend/app/api/v1/standards.py

from typing import Optional, Literal

from fastapi import APIRouter, HTTPException, Query

from app.services.standards_service import get_rounded_pack

router = APIRouter(prefix="/standards", tags=["Standards"])


@router.get("/{bodyweight}")
async def get_standards(
    bodyweight: float,
    gender: Optional[str] = "male",
    unit: Optional[Literal["kg", "lbs"]] = Query(None),
):
    if bodyweight <= 0:
        raise HTTPException(status_code=400, detail="Bodyweight must be positive")

    if gender not in ["male", "female"]:
        raise HTTPException(status_code=400, detail="Gender must be 'male' or 'female'")

    chosen_unit = unit or "kg"
    return await get_rounded_pack(bodyweight=bodyweight, gender=gender, unit=chosen_unit)
