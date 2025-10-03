# backend/app/schemas/routine.py

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, FieldSerializationInfo, field_serializer, field_validator

from app.utils.datetime import ensure_aware_utc
from app.utils.storage import build_public_url, normalize_storage_key


class ScenarioSet(BaseModel):
    scenario_id: str
    name: str
    sets: int = Field(..., ge=0)
    reps: int = Field(..., ge=0)

    model_config = {"from_attributes": True}


class RoutineBase(BaseModel):
    name: str
    image_url: Optional[str] = None


class RoutineCreate(RoutineBase):
    scenarios: List[ScenarioSet]

    @field_validator("image_url", mode="before")
    @classmethod
    def _normalize_image_url(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = normalize_storage_key(value)
        return normalized if normalized is not None else value


class RoutineUpdate(RoutineBase):
    scenarios: Optional[List[ScenarioSet]] = None

    @field_validator("image_url", mode="before")
    @classmethod
    def _normalize_image_url(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = normalize_storage_key(value)
        return normalized if normalized is not None else value


class RoutineRead(RoutineBase):
    id: UUID
    user_id: Optional[UUID] = None
    created_at: datetime
    scenarios: List[ScenarioSet]

    model_config = {"from_attributes": True}

    @field_validator("created_at", mode="after")
    def _validate_created_at(cls, value: datetime) -> datetime:
        return ensure_aware_utc(value, field_name="created_at", allow_naive=True)

    @field_serializer("image_url")
    def _serialize_image_url(
        self, value: Optional[str], info: FieldSerializationInfo
    ) -> Optional[str]:
        return build_public_url(value)
