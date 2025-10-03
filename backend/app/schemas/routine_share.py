# backend/app/schemas/routine_share.py

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, FieldSerializationInfo, field_serializer, field_validator

from app.schemas.routine import ScenarioSet
from app.utils.datetime import ensure_aware_utc
from app.utils.storage import build_public_url


class RoutineShareRead(BaseModel):
    code: str = Field(..., min_length=4, max_length=32)
    name: str
    image_url: Optional[str] = None
    scenarios: List[ScenarioSet]
    created_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("created_at", mode="after")
    def _validate_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)

    @field_serializer("image_url")
    def _serialize_image_url(
        self, value: Optional[str], info: FieldSerializationInfo
    ) -> Optional[str]:
        return build_public_url(value)


class RoutineImportRequest(BaseModel):
    share_code: str = Field(..., min_length=4, max_length=32)
