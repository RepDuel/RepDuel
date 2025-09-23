# backend/app/schemas/energy.py

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_validator

from app.utils.datetime import ensure_aware_utc


class DailyEnergyEntry(BaseModel):
    date: date
    total_energy: float

    model_config = {"from_attributes": True}


class EnergySubmit(BaseModel):
    user_id: UUID
    energy: float
    rank: str


class EnergyEntry(BaseModel):
    id: UUID
    user_id: UUID
    energy: float
    created_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("created_at", mode="after")
    def _validate_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)


class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    display_name: Optional[str] = None
    total_energy: float
    avatar_url: Optional[str] = None
    user_rank: Optional[str] = None

    model_config = {"from_attributes": True}
