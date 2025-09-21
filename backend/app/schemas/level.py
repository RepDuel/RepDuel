# backend/app/schemas/level.py

from typing import Literal

from pydantic import BaseModel, Field


class LevelProgress(BaseModel):
    level: int = Field(..., ge=1)
    xp: int = Field(..., ge=0)
    xp_to_next: int = Field(..., ge=0)
    progress_pct: float = Field(..., ge=0.0, le=1.0)
    xp_gained_this_week: int = Field(..., ge=0)


class AwardXPRequest(BaseModel):
    amount: int = Field(..., gt=0)
    reason: str | None = Field(default=None, max_length=255)
    idempotency_key: str | None = Field(default=None, max_length=255)
    source_type: str | None = Field(default=None, max_length=64)
    source_id: str | None = Field(default=None, max_length=255)


class AwardXPResponse(BaseModel):
    awarded: bool
    reason: Literal["created", "idempotent_replay"]
    progress: LevelProgress
