# backend/app/schemas/score.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, field_validator

from app.schemas.user import UserRead
from app.utils.datetime import ensure_aware_utc


class ScoreCreate(BaseModel):
    """Payload submitted when a user records a new score."""

    weight_lifted: float
    scenario_id: str | None = None
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

    @field_validator("created_at", mode="after")
    def _validate_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)


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

    @field_validator("created_at", mode="after")
    def _validate_user_score_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)
