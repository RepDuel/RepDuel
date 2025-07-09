from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class EnergyEntry(BaseModel):
    id: UUID
    user_id: UUID
    energy: float
    created_at: datetime

    class Config:
        orm_mode = True


class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    total_energy: float

    class Config:
        orm_mode = True
