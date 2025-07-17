from datetime import datetime
from uuid import UUID

from app.schemas.user import UserRead
from pydantic import BaseModel


class ScoreCreate(BaseModel):
    user_id: UUID
    scenario_id: str
    weight_lifted: float


class ScoreOut(BaseModel):
    id: int
    user_id: UUID
    scenario_id: str
    weight_lifted: float
    created_at: datetime

    model_config = {"from_attributes": True}


class ScoreReadWithUser(BaseModel):
    id: int
    weight_lifted: float
    created_at: datetime
    user: UserRead

    class Config:
        from_attributes = True
