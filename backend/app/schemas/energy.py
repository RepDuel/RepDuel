from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class EnergySubmit(BaseModel):
    user_id: UUID
    energy: float
    rank: str


class EnergyEntry(BaseModel):
    id: UUID
    user_id: UUID
    energy: float
    created_at: datetime

    model_config = {
        "from_attributes": True
    }


class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    total_energy: float

    model_config = {
        "from_attributes": True
    }
