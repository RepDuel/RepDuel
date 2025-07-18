from pydantic import BaseModel
from typing import List
from uuid import UUID
from datetime import datetime

# Model to represent the data for each routine scenario when submitting a routine
class RoutineScenarioSubmission(BaseModel):
    scenario_id: str  # ID of the scenario (string)
    sets: int  # Number of sets
    reps: int  # Number of reps per set
    weight: float  # Weight lifted in kg
    total_volume: float  # Total volume (weight * reps * sets)

    class Config:
        orm_mode = True  # To allow compatibility with SQLAlchemy models


# Model to represent the complete routine submission
class RoutineSubmission(BaseModel):
    routine_id: UUID  # ID of the routine being submitted
    user_id: UUID  # ID of the user submitting the routine
    duration: float  # Duration of the routine in minutes
    completion_timestamp: datetime  # Timestamp when the routine was completed
    scenarios: List[RoutineScenarioSubmission]  # List of routine scenarios with data
    status: str  # Can be 'completed' or 'partial'

    class Config:
        orm_mode = True
