from typing import List, Optional
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel


class RoutineBase(BaseModel):
    name: str


class RoutineCreate(RoutineBase):
    scenario_ids: List[UUID]


class RoutineUpdate(RoutineBase):
    scenario_ids: Optional[List[UUID]] = None


class RoutineInDBBase(RoutineBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True  # Use for Pydantic v2 compatibility


class RoutineRead(RoutineInDBBase):
    scenario_ids: List[UUID]
