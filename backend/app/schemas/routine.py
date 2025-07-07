# backend/app/schemas/routine.py

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

    class Config:
        from_attributes = True
