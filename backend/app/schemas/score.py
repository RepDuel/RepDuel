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
    is_bodyweight: bool
    created_at: datetime
    sets: int | None = None
    reps: int | None = None

    model_config = {"from_attributes": True}


class ScoreCreateResponse(BaseModel):
    score: ScoreOut
    is_personal_best: bool
    previous_best_score_value: float | None = None
    previous_best_weight_lifted: float | None = None
    previous_best_reps: int | None = None
    previous_best_sets: int | None = None



class ScoreReadWithUser(BaseModel):
    id: int
    weight_lifted: float
    score_value: float
    created_at: datetime
    user: UserRead

    class Config:
        from_attributes = True
