# backend/app/schemas/routine.py

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.utils.datetime import ensure_aware_utc


class ScenarioSet(BaseModel):
    scenario_id: str
    name: str
    sets: int = Field(..., ge=0)
    reps: int = Field(..., ge=0)

    model_config = {"from_attributes": True}


class RoutineBase(BaseModel):
    name: str
    image_url: Optional[str] = None


class RoutineCreate(RoutineBase):
    scenarios: List[ScenarioSet]


class RoutineUpdate(RoutineBase):
    scenarios: Optional[List[ScenarioSet]] = None


class RoutineRead(RoutineBase):
    id: UUID
    user_id: Optional[UUID] = None
    created_at: datetime
    scenarios: List[ScenarioSet]

    model_config = {"from_attributes": True}

    @field_validator("created_at", mode="after")
    def _validate_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)
