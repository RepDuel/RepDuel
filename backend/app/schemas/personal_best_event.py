# backend/app/schemas/personal_best_event.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, field_validator

from app.utils.datetime import ensure_aware_utc


class PersonalBestEventRead(BaseModel):
    id: int
    user_id: UUID
    scenario_id: str
    score_value: float
    weight_lifted: float
    is_bodyweight: bool
    created_at: datetime
    reps: int | None = None

    model_config = {"from_attributes": True}

    @field_validator("created_at", mode="after")
    def _validate_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)
