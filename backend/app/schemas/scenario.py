from pydantic import BaseModel
from typing import Optional
from uuid import UUID

class ScenarioBase(BaseModel):
    name: str
    description: Optional[str] = None


class ScenarioCreate(ScenarioBase):
    pass


class ScenarioUpdate(ScenarioBase):
    pass


class ScenarioInDBBase(ScenarioBase):
    id: int

    class Config:
        from_attributes = True


class Scenario(ScenarioInDBBase):
    pass


class ScenarioOut(ScenarioInDBBase):
    id: UUID
    name: str
    description: str | None = None

    class Config:
        from_attributes = True
