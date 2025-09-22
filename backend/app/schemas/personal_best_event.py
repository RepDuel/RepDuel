# backend/app/schemas/personal_best_event.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


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
