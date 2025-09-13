# backend/app/schemas/energy.py

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


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


class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    total_energy: float
    avatar_url: Optional[str] = None
    user_rank: Optional[str] = None

    model_config = {"from_attributes": True}
