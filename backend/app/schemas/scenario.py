from typing import Optional
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
    id: UUID
    name: str
    description: str | None = None

    model_config = {"from_attributes": True}
