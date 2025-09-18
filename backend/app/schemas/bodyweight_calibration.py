# backend/app/schemas/bodyweight_calibration.py

from pydantic import BaseModel


class BodyweightCalibrationRead(BaseModel):
    beginner_50: int
    elite_50: int
    beginner_140: int
    elite_140: int
    intermediate_95: int

    model_config = {"from_attributes": True}

