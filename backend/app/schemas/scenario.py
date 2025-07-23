# backend/app/schemas/scenario.py

from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class ScenarioBase(BaseModel):
    name: str
    description: Optional[str] = None


class ScenarioCreate(ScenarioBase):
    pass


class ScenarioUpdate(ScenarioBase):
    pass


class ScenarioInDBBase(ScenarioBase):
    id: int

    model_config = {"from_attributes": True}


class Scenario(ScenarioInDBBase):
    pass


class ScenarioOut(ScenarioInDBBase):
    id: str
    name: str
    description: str | None = None

    model_config = {"from_attributes": True}


class ScenarioRead(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    multiplier: Optional[float] = None
    primary_muscles: List[str]  # You can change this to a more detailed model of Muscle if needed
    secondary_muscles: List[str]  # Same here
    equipment: List[str]  # Change this to a detailed model of Equipment if necessary

    class Config:
        from_attributes = True
