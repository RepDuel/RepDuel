from typing import List, Optional
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


class ScenarioSet(BaseModel):
    scenario_id: UUID
    sets: int = Field(..., ge=0)
    reps: int = Field(..., ge=0)


class RoutineBase(BaseModel):
    name: str


class RoutineCreate(RoutineBase):
    scenarios: List[ScenarioSet]


class RoutineUpdate(RoutineBase):
    scenarios: Optional[List[ScenarioSet]] = None


class RoutineInDBBase(RoutineBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True


class RoutineRead(RoutineInDBBase):
    scenarios: List[ScenarioSet]
