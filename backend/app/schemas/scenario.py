# backend/app/schemas/scenario.py

from typing import List, Optional

from pydantic import BaseModel, ConfigDict

from app.schemas.bodyweight_calibration import BodyweightCalibrationRead

class ScenarioBase(BaseModel):
    name: str
    description: Optional[str] = None


class ScenarioCreate(ScenarioBase):
    pass


class ScenarioUpdate(ScenarioBase):
    pass


class ScenarioInDBBase(ScenarioBase):
    id: int
    model_config = ConfigDict(from_attributes=True)


class Scenario(ScenarioInDBBase):
    pass


class ScenarioOut(ScenarioInDBBase):
    id: str
    name: str
    description: str | None = None
    model_config = ConfigDict(from_attributes=True)


class ScenarioRead(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    multiplier: Optional[float] = None
    volume_multiplier: Optional[float] = None
    is_bodyweight: bool
    primary_muscles: List[str]
    secondary_muscles: List[str]
    equipment: List[str]
    calibration: Optional[BodyweightCalibrationRead] = None

    model_config = ConfigDict(from_attributes=True)
