# backend/app/schemas/energy.py

from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel

# For energy graph display by day
class DailyEnergyEntry(BaseModel):
    date: date
    total_energy: float

    model_config = {"from_attributes": True}


# For submitting energy updates from frontend
class EnergySubmit(BaseModel):
    user_id: UUID
    energy: float
    rank: str


# Full energy entry, used when fetching full history
class EnergyEntry(BaseModel):
    id: UUID
    user_id: UUID
    energy: float
    created_at: datetime

    model_config = {"from_attributes": True}


# --- THIS IS THE FIX ---
# Used in energy leaderboard
class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    total_energy: float
    avatar_url: Optional[str] = None # Added for displaying profile pics
    user_rank: Optional[str] = None # Added for displaying rank badge

    model_config = {"from_attributes": True}
# --- END OF FIX ---