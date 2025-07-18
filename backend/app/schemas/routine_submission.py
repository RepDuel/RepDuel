from pydantic import BaseModel
from uuid import UUID
from typing import List
from datetime import datetime

# Model for routine scenario submission
class RoutineScenarioSubmission(BaseModel):
    scenario_id: str  # ID of the scenario (string)
    sets: int  # Number of sets
    reps: int  # Number of reps per set
    weight: float  # Weight lifted in kg
    total_volume: float  # Total volume (weight * reps * sets)

    class Config:
        orm_mode = True  # To allow compatibility with SQLAlchemy models


# Model for creating a routine submission
class RoutineSubmissionCreate(BaseModel):
    routine_id: UUID
    user_id: UUID
    duration: float
    completion_timestamp: datetime
    status: str  # 'completed' or 'partial'
    scenarios: List[RoutineScenarioSubmission]  # List of routine scenarios with data

    class Config:
        orm_mode = True


# Model for reading a routine submission (response model)
class RoutineSubmissionRead(BaseModel):
    routine_id: UUID
    user_id: UUID
    duration: float
    completion_timestamp: datetime
    status: str
    scenarios: List[RoutineScenarioSubmission]  # List of scenarios with data

    class Config:
        orm_mode = True
