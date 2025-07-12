from datetime import date, datetime
from uuid import UUID
from pydantic import BaseModel


# For energy graph display by day
class DailyEnergyEntry(BaseModel):
    date: date
    total_energy: float


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

    class Config:
        from_attributes = True


# Used in energy leaderboard
class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    total_energy: float

    class Config:
        from_attributes = True
from datetime import date, datetime
from uuid import UUID
from pydantic import BaseModel


# For energy graph display by day
class DailyEnergyEntry(BaseModel):
    date: date
    total_energy: float


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

    class Config:
        from_attributes = True


# Used in energy leaderboard
class EnergyLeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    total_energy: float

    class Config:
        from_attributes = True
