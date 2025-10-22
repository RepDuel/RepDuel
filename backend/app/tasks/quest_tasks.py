"""Celery tasks for quest aggregation and progress updates."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any, Mapping
from uuid import UUID, uuid4

try:  # pragma: no cover - use Celery logger when available
    from celery.utils.log import get_task_logger  # type: ignore
except ImportError:  # pragma: no cover - fallback for environments without Celery
    import logging

    def get_task_logger(name: str):
        return logging.getLogger(name)

from app.core.celery_app import celery_app
from app.db.session import async_session
from app.services import quest_service
from app.utils.datetime import ensure_optional_aware_utc

logger = get_task_logger(__name__)


def _parse_timestamp(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        logger.warning("Unable to parse timestamp %s; defaulting to UTC now", value)
        return None
    return ensure_optional_aware_utc(parsed, field_name="occurred_at", allow_naive=True)


async def _process_submission_event(payload: Mapping[str, Any]) -> None:
    submission_id = payload.get("submission_id")
    user_id = payload.get("user_id")
    occurred_at = payload.get("occurred_at")
    if not submission_id or not user_id:
        logger.error("Submission event missing identifiers: %s", payload)
        return

    try:
        submission_uuid = UUID(str(submission_id))
        user_uuid = UUID(str(user_id))
    except (ValueError, TypeError):
        logger.exception("Invalid identifiers in submission event: %s", payload)
        return

    occurred_ts = _parse_timestamp(str(occurred_at))

    async with async_session() as session:
        try:
            await quest_service.process_routine_submission_event(
                session,
                submission_id=submission_uuid,
                user_id=user_uuid,
                now=occurred_ts,
            )
        except Exception:
            logger.exception(
                "Failed to process quest submission event", extra={"submission_id": str(submission_uuid)}
            )
            raise


@celery_app.task(
    name="quests.process_routine_submission",
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_jitter=True,
    acks_late=True,
)
def process_routine_submission(self, payload: Mapping[str, Any]) -> str:
    """Process a workout submission event and update quest aggregates."""

    event_id = payload.get("event_id")
    if not event_id:
        event_id = str(uuid4())
    logger.debug("Processing quest submission event", extra={"event_id": event_id})
    asyncio.run(_process_submission_event(payload))
    return event_id


def enqueue_routine_submission_event(
    *,
    user_id: UUID,
    submission_id: UUID,
    occurred_at: datetime | None = None,
    event_id: UUID | None = None,
) -> str:
    """Publish a quest submission event to the queue."""

    payload = {
        "event_id": str(event_id or uuid4()),
        "user_id": str(user_id),
        "submission_id": str(submission_id),
        "occurred_at": (
            ensure_optional_aware_utc(occurred_at, field_name="occurred_at", allow_naive=True)
            or datetime.now(timezone.utc)
        ).isoformat(),
    }
    process_routine_submission.delay(payload)
    return payload["event_id"]


__all__ = ["process_routine_submission", "enqueue_routine_submission_event"]
