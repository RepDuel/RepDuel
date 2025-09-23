# backend/app/schemas/routine_submission.py

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.utils.datetime import ensure_aware_utc


class RoutineScenarioSubmission(BaseModel):
    scenario_id: str
    sets: int
    reps: int
    weight: float
    total_volume: float

    model_config = {"from_attributes": True}


class RoutineSubmissionCreate(BaseModel):
    routine_id: Optional[UUID] = None
    user_id: UUID
    duration: float
    completion_timestamp: datetime
    status: str
    scenarios: List[RoutineScenarioSubmission] = Field(
        ..., alias="scenario_submissions"
    )

    model_config = {"from_attributes": True, "populate_by_name": True}

    @field_validator("completion_timestamp", mode="after")
    def _validate_completion_timestamp(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="completion_timestamp")


class RoutineSubmissionRead(BaseModel):
    routine_id: Optional[UUID] = None
    user_id: UUID
    duration: float
    completion_timestamp: datetime
    status: str
    title: str
    scenarios: List[RoutineScenarioSubmission] = Field(
        ..., alias="scenario_submissions"
    )

    model_config = {"from_attributes": True, "populate_by_name": True}

    @field_validator("completion_timestamp", mode="after")
    def _validate_read_timestamp(cls, value: datetime) -> datetime:
        return ensure_aware_utc(
            value, field_name="completion_timestamp", allow_naive=True
        )
