# backend/app/schemas/quest.py

"""Pydantic schemas for quest endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from app.models.quest import QuestCadence, QuestMetric, QuestStatus, UserQuest


class QuestTemplateSummary(BaseModel):
    id: UUID
    code: str
    title: str
    description: str | None = None
    cadence: QuestCadence
    metric: QuestMetric
    target_value: int
    reward_xp: int
    auto_claim: bool
    available_from: datetime | None = None
    expires_at: datetime | None = None

    model_config = {
        "use_enum_values": True,
    }

    @classmethod
    def from_model(cls, quest: UserQuest) -> "QuestTemplateSummary":
        template = quest.template
        if template is None:
            raise ValueError("Quest template must be loaded")
        return cls(
            id=template.id,
            code=template.code,
            title=template.title,
            description=template.description,
            cadence=QuestCadence(template.cadence),
            metric=QuestMetric(template.metric),
            target_value=template.target_value,
            reward_xp=template.reward_xp,
            auto_claim=template.auto_claim,
            available_from=template.available_from,
            expires_at=template.expires_at,
        )


class QuestInstance(BaseModel):
    id: UUID
    status: QuestStatus
    progress: int
    required: int
    progress_pct: float
    available_from: datetime
    expires_at: datetime | None = None
    cycle_start: datetime
    cycle_end: datetime | None = None
    completed_at: datetime | None = None
    reward_claimed_at: datetime | None = None
    last_progress_at: datetime | None = None
    reward_xp: int
    template: QuestTemplateSummary

    model_config = {
        "use_enum_values": True,
    }

    @classmethod
    def from_model(cls, quest: UserQuest) -> "QuestInstance":
        if quest.template is None:
            raise ValueError("Quest template must be loaded")
        summary = QuestTemplateSummary.from_model(quest)
        required = max(0, quest.required_value)
        progress = max(0, quest.progress_value)
        pct = 1.0 if required == 0 else min(1.0, progress / required)
        return cls(
            id=quest.id,
            status=QuestStatus(quest.status),
            progress=progress,
            required=required,
            progress_pct=pct,
            available_from=quest.available_from,
            expires_at=quest.expires_at,
            cycle_start=quest.cycle_start,
            cycle_end=quest.cycle_end,
            completed_at=quest.completed_at,
            reward_claimed_at=quest.reward_claimed_at,
            last_progress_at=quest.last_progress_at,
            reward_xp=summary.reward_xp,
            template=summary,
        )


class QuestListResponse(BaseModel):
    generated_at: datetime
    quests: list[QuestInstance]

