# backend/app/schemas/routine_submission.py

from datetime import datetime
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field


class RoutineScenarioSubmission(BaseModel):
    scenario_id: str
    sets: int
    reps: int
    weight: float
    total_volume: float

    model_config = {"from_attributes": True}


class RoutineSubmissionCreate(BaseModel):
    routine_id: UUID
    user_id: UUID
    duration: float
    completion_timestamp: datetime
    status: str
    scenarios: List[RoutineScenarioSubmission] = Field(..., alias="scenario_submissions")

    model_config = {"from_attributes": True, "populate_by_name": True}


class RoutineSubmissionRead(BaseModel):
    routine_id: UUID
    user_id: UUID
    duration: float
    completion_timestamp: datetime
    status: str
    title: str
    scenarios: List[RoutineScenarioSubmission] = Field(..., alias="scenario_submissions")

    model_config = {"from_attributes": True, "populate_by_name": True}
