from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class EnergyEntry(BaseModel):
    user_id: UUID
    energy: float
    created_at: datetime

    model_config = {
        "from_attributes": True
    }
