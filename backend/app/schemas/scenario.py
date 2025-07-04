from pydantic import BaseModel
from typing import Optional


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
    pass
