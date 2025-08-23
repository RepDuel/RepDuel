# backend/app/schemas/score.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from app.schemas.user import UserRead


class ScoreCreate(BaseModel):
    user_id: UUID
    weight_lifted: float
    sets: int | None = None
    reps: int | None = None


class ScoreOut(BaseModel):
    id: int
    user_id: UUID
    scenario_id: str
    weight_lifted: float
    score_value: float
    created_at: datetime
    sets: int | None = None
    reps: int | None = None

    model_config = {"from_attributes": True}


class ScoreReadWithUser(BaseModel):
    id: int
    weight_lifted: float
    score_value: float
    created_at: datetime
    user: UserRead

    class Config:
        from_attributes = True
