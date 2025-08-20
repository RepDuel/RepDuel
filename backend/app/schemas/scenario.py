# backend/app/schemas/scenario.py

from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


# No changes needed in these base classes
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


# --- THIS IS THE SCHEMA THAT NEEDS TO BE FIXED ---
# This is the schema used by your GET /scenarios/{id}/details endpoint.
# It must contain all the fields the frontend needs.
class ScenarioRead(BaseModel):
    id: str
    name: str
    description: Optional[str] = None

    # This field is now used for rank calculation
    multiplier: Optional[float] = None

    # --- ADDED THE NEW FIELDS HERE ---
    volume_multiplier: Optional[float] = None
    is_bodyweight: bool
    # --- END OF ADDED FIELDS ---

    # These lists are likely populated by a custom database query, they can remain
    primary_muscles: List[str]
    secondary_muscles: List[str]
    equipment: List[str]

    class Config:
        from_attributes = True
