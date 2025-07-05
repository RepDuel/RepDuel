from pydantic import BaseModel
from datetime import datetime
from uuid import UUID

class ScoreCreate(BaseModel):
    user_id: UUID
    scenario_id: UUID
    weight_lifted: float

class ScoreOut(BaseModel):
    id: int
    user_id: UUID
    scenario_id: UUID
    weight_lifted: float
    created_at: datetime

    class Config:
        from_attributes = True
