# backend/app/services/quest_service.py

"""Business logic for XP quest templates and user progress."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Iterable, Sequence
from uuid import UUID

from sqlalchemy import and_, case, func, select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.quest import (
    QuestCadence,
    QuestMetric,
    QuestStatus,
    QuestTemplate,
    UserQuest,
)
from app.models.daily_workout_aggregate import DailyWorkoutAggregate
from app.models.routine_submission import RoutineSubmission
from app.services.level_service import award_xp
from app.utils.datetime import ensure_optional_aware_utc

UTC = timezone.utc

DAILY_WORKOUT_QUEST_CODE = "daily_30_min_workout"
WEEKLY_WORKOUT_QUEST_CODE = "weekly_30_min_workout_three_days"
WORKOUT_SINGLE_SESSION_CODES = {
    DAILY_WORKOUT_QUEST_CODE,
    WEEKLY_WORKOUT_QUEST_CODE,
}
QUALIFYING_MINUTES = 30


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _as_utc(dt: datetime | None) -> datetime | None:
    return ensure_optional_aware_utc(dt, field_name="timestamp", allow_naive=True)


def _start_of_day(ts: datetime) -> datetime:
    ts_utc = ts.astimezone(UTC)
    return ts_utc.replace(hour=0, minute=0, second=0, microsecond=0)


def _start_of_week(ts: datetime) -> datetime:
    day_start = _start_of_day(ts)
    return day_start - timedelta(days=day_start.weekday())


def _cycle_window(
    template: QuestTemplate, now: datetime
) -> tuple[datetime, datetime | None] | None:
    cadence = QuestCadence(template.cadence)
    if cadence is QuestCadence.DAILY:
        start = _start_of_day(now)
        end = start + timedelta(days=1)
        return start, end
    if cadence is QuestCadence.WEEKLY:
        start = _start_of_week(now)
        end = start + timedelta(days=7)
        return start, end

    available_from = _as_utc(template.available_from) or now
    if available_from > now:
        return None
    return available_from, _as_utc(template.expires_at)


async def _fetch_available_templates(
    db: AsyncSession, now: datetime
) -> list[QuestTemplate]:
    result = await db.execute(
        select(QuestTemplate).where(QuestTemplate.is_active.is_(True))
    )
    templates = list(result.scalars().all())
    available: list[QuestTemplate] = []
    for template in templates:
        start = _as_utc(template.available_from)
        end = _as_utc(template.expires_at)
        if start and now < start:
            continue
        if end and now >= end:
            continue
        available.append(template)
    return available


async def _ensure_user_quests(
    db: AsyncSession, user_id: UUID, now: datetime
) -> Sequence[UserQuest]:
    templates = await _fetch_available_templates(db, now)
    ensured: list[UserQuest] = []
    created = False
    for template in templates:
        window = _cycle_window(template, now)
        if window is None:
            continue
        cycle_start, cycle_end = window
        result = await db.execute(
            select(UserQuest)
            .options(selectinload(UserQuest.template))
            .where(
                and_(
                    UserQuest.user_id == user_id,
                    UserQuest.template_id == template.id,
                    UserQuest.cycle_start == cycle_start,
                )
            )
        )
        quest = result.scalars().first()
        if quest:
            ensured.append(quest)
            continue
        quest = UserQuest(
            user_id=user_id,
            template_id=template.id,
            status=QuestStatus.ACTIVE.value,
            progress_value=0,
            required_value=template.target_value,
            cycle_start=cycle_start,
            cycle_end=cycle_end,
            available_from=(
                cycle_start
                if QuestCadence(template.cadence) is not QuestCadence.LIMITED
                else _as_utc(template.available_from) or cycle_start
            ),
            expires_at=(
                cycle_end
                if QuestCadence(template.cadence) is not QuestCadence.LIMITED
                else _as_utc(template.expires_at)
            ),
            created_at=now,
            updated_at=now,
        )
        quest.template = template
        db.add(quest)
        created = True
        ensured.append(quest)
    if created:
        await db.flush()
        await db.commit()
    return ensured


async def _claim_reward(
    db: AsyncSession,
    quest: UserQuest,
    template: QuestTemplate,
    now: datetime,
) -> None:
    if quest.reward_claimed_at:
        if quest.status != QuestStatus.CLAIMED.value:
            quest.status = QuestStatus.CLAIMED.value
            quest.updated_at = now
            await db.commit()
        return

    quest.reward_claimed_at = now
    quest.completed_at = quest.completed_at or now
    quest.status = QuestStatus.CLAIMED.value
    quest.updated_at = now
    await db.flush()

    outcome = await award_xp(
        db,
        quest.user_id,
        template.reward_xp,
        reason=f"quest:{template.code}",
        source_type="quest",
        source_id=str(quest.id),
    )
    if not outcome.awarded and outcome.reason != "idempotent_replay":
        # Unexpected failure - keep quest in completed state for manual retry.
        quest.status = QuestStatus.COMPLETED.value
        await db.commit()
        return
    await db.refresh(quest)


async def _sync_quests(
    db: AsyncSession, quests: Iterable[UserQuest], now: datetime
) -> None:
    pending_commit = False
    for quest in quests:
        template = quest.template
        if template is None:
            await db.refresh(quest, attribute_names=["template"])
            template = quest.template
        if template is None:
            continue

        if quest.status in (
            QuestStatus.CLAIMED.value,
            QuestStatus.EXPIRED.value,
        ):
            continue

        expires_at = _as_utc(quest.expires_at)
        if expires_at and now >= expires_at:
            quest.status = QuestStatus.EXPIRED.value
            quest.updated_at = now
            pending_commit = True
            continue

        if quest.required_value <= 0:
            quest.completed_at = quest.completed_at or now
        if quest.progress_value >= max(1, quest.required_value):
            quest.completed_at = quest.completed_at or now
            if template.auto_claim:
                await _claim_reward(db, quest, template, now)
            else:
                if quest.status != QuestStatus.COMPLETED.value:
                    quest.status = QuestStatus.COMPLETED.value
                    quest.updated_at = now
                    pending_commit = True
    if pending_commit:
        await db.commit()


async def get_user_quests(
    db: AsyncSession, user_id: UUID, *, now: datetime | None = None
) -> list[UserQuest]:
    timestamp = now or _utc_now()
    await _ensure_user_quests(db, user_id, timestamp)
    result = await db.execute(
        select(UserQuest)
        .options(selectinload(UserQuest.template))
        .where(UserQuest.user_id == user_id)
        .order_by(UserQuest.available_from.desc(), UserQuest.created_at.desc())
    )
    quests = list(result.scalars().all())
    await _sync_quests(db, quests, timestamp)
    return quests


async def _get_daily_aggregate(
    db: AsyncSession, user_id: UUID, day_start: datetime
) -> DailyWorkoutAggregate | None:
    result = await db.execute(
        select(DailyWorkoutAggregate).where(
            and_(
                DailyWorkoutAggregate.user_id == user_id,
                DailyWorkoutAggregate.day == day_start,
            )
        )
    )
    return result.scalars().first()


async def _upsert_daily_aggregate(
    db: AsyncSession,
    user_id: UUID,
    *,
    day_start: datetime,
    longest_session_minutes: int,
    qualified: bool,
    timestamp: datetime,
) -> DailyWorkoutAggregate:
    aggregate = await _get_daily_aggregate(db, user_id, day_start)
    if aggregate is None:
        aggregate = DailyWorkoutAggregate(
            user_id=user_id,
            day=day_start,
            longest_session_minutes=longest_session_minutes,
            qualified_30=qualified,
            created_at=timestamp,
            updated_at=timestamp,
        )
        db.add(aggregate)
    else:
        if (
            aggregate.longest_session_minutes != longest_session_minutes
            or aggregate.qualified_30 != qualified
        ):
            aggregate.longest_session_minutes = longest_session_minutes
            aggregate.qualified_30 = qualified
            aggregate.updated_at = timestamp
    await db.flush()
    return aggregate


async def _recalculate_daily_aggregate(
    db: AsyncSession,
    user_id: UUID,
    *,
    day_start: datetime,
    timestamp: datetime,
) -> DailyWorkoutAggregate | None:
    day_end = day_start + timedelta(days=1)
    query = (
        select(
            func.coalesce(func.max(RoutineSubmission.duration), 0.0),
            func.max(
                case(
                    (RoutineSubmission.duration >= QUALIFYING_MINUTES, 1),
                    else_=0,
                )
            ),
        )
        .where(RoutineSubmission.user_id == user_id)
        .where(RoutineSubmission.completion_timestamp >= day_start)
        .where(RoutineSubmission.completion_timestamp < day_end)
    )
    result = await db.execute(query)
    row = result.first()
    if row is None:
        return await _get_daily_aggregate(db, user_id, day_start)
    max_duration, qualified_flag = row
    longest_minutes = int(round(float(max_duration or 0.0)))
    qualified = bool(qualified_flag) or longest_minutes >= QUALIFYING_MINUTES
    return await _upsert_daily_aggregate(
        db,
        user_id,
        day_start=day_start,
        longest_session_minutes=longest_minutes,
        qualified=qualified,
        timestamp=timestamp,
    )


async def _aggregate_submission_metrics(
    db: AsyncSession,
    user_id: UUID,
    *,
    start: datetime,
    end: datetime | None,
) -> tuple[int, int]:
    query = (
        select(
            func.coalesce(func.count(RoutineSubmission.id), 0),
            func.coalesce(func.sum(RoutineSubmission.duration), 0.0),
        )
        .where(RoutineSubmission.user_id == user_id)
        .where(RoutineSubmission.completion_timestamp >= start)
    )
    if end is not None:
        query = query.where(RoutineSubmission.completion_timestamp < end)
    result = await db.execute(query)
    row = result.first()
    if row is None:
        return 0, 0
    count, total_minutes = row
    return int(count or 0), int(round(float(total_minutes or 0.0)))


async def _refresh_metric_quests_from_history(
    db: AsyncSession,
    user_id: UUID,
    metric: QuestMetric,
    now: datetime,
) -> None:
    await _ensure_user_quests(db, user_id, now)
    result = await db.execute(
        select(UserQuest)
        .join(UserQuest.template)
        .options(selectinload(UserQuest.template))
        .where(
            and_(
                UserQuest.user_id == user_id,
                QuestTemplate.metric == metric.value,
            )
        )
    )
    quests = list(result.scalars().all())
    if not quests:
        return

    stats_cache: dict[tuple[datetime, datetime | None], tuple[int, int]] = {}
    changed = False
    for quest in quests:
        template = quest.template
        if template is None:
            await db.refresh(quest, attribute_names=["template"])
            template = quest.template
        if template is None:
            continue
        if template.code in WORKOUT_SINGLE_SESSION_CODES:
            continue

        key = (quest.cycle_start, quest.cycle_end)
        if key not in stats_cache:
            stats_cache[key] = await _aggregate_submission_metrics(
                db,
                user_id,
                start=quest.cycle_start,
                end=quest.cycle_end,
            )
        count, minutes = stats_cache[key]
        required = max(0, quest.required_value)
        raw_progress = count if metric is QuestMetric.WORKOUTS_COMPLETED else minutes
        progress = min(required, raw_progress) if required > 0 else raw_progress
        if progress != quest.progress_value:
            quest.progress_value = progress
            quest.last_progress_at = now
            quest.updated_at = now
            changed = True

    if changed:
        await db.flush()
    await _sync_quests(db, quests, now)


async def _refresh_workout_quests(
    db: AsyncSession,
    user_id: UUID,
    *,
    completed_at: datetime,
    now: datetime,
) -> None:
    day_start = _start_of_day(completed_at)
    aggregate = await _get_daily_aggregate(db, user_id, day_start)
    if aggregate is None:
        return

    await _ensure_user_quests(db, user_id, now)
    result = await db.execute(
        select(UserQuest)
        .join(UserQuest.template)
        .options(selectinload(UserQuest.template))
        .where(
            and_(
                UserQuest.user_id == user_id,
                QuestTemplate.code.in_(WORKOUT_SINGLE_SESSION_CODES),
            )
        )
    )
    quests = list(result.scalars().all())
    if not quests:
        return

    week_start = _start_of_week(completed_at)
    week_end = week_start + timedelta(days=7)
    result = await db.execute(
        select(DailyWorkoutAggregate).where(
            and_(
                DailyWorkoutAggregate.user_id == user_id,
                DailyWorkoutAggregate.day >= week_start,
                DailyWorkoutAggregate.day < week_end,
            )
        )
    )
    weekly_rows = list(result.scalars().all())
    qualified_days = sum(1 for row in weekly_rows if row.qualified_30)

    changed = False
    for quest in quests:
        template = quest.template
        if template is None:
            await db.refresh(quest, attribute_names=["template"])
            template = quest.template
        if template is None:
            continue

        if template.code == DAILY_WORKOUT_QUEST_CODE:
            required = max(1, template.target_value)
            progress = min(required, aggregate.longest_session_minutes)
        elif template.code == WEEKLY_WORKOUT_QUEST_CODE:
            required = max(1, template.target_value)
            progress = min(required, qualified_days)
        else:
            continue

        if quest.progress_value != progress:
            quest.progress_value = progress
            quest.last_progress_at = completed_at
            quest.updated_at = now
            changed = True

    if changed:
        await db.flush()
    await _sync_quests(db, quests, now)


async def process_routine_submission_event(
    db: AsyncSession,
    *,
    submission_id: UUID,
    user_id: UUID | None = None,
    now: datetime | None = None,
) -> None:
    """Recompute quest state for a workout submission."""

    timestamp = now or _utc_now()
    result = await db.execute(
        select(RoutineSubmission).where(RoutineSubmission.id == submission_id)
    )
    submission = result.scalars().first()
    if submission is None:
        return

    submission_user_id = submission.user_id
    if user_id and user_id != submission_user_id:
        submission_user_id = submission.user_id

    completion_ts = _as_utc(submission.completion_timestamp) or timestamp
    day_start = _start_of_day(completion_ts)

    await _ensure_user_quests(db, submission_user_id, timestamp)
    await _recalculate_daily_aggregate(
        db,
        submission_user_id,
        day_start=day_start,
        timestamp=timestamp,
    )
    await _refresh_metric_quests_from_history(
        db,
        submission_user_id,
        QuestMetric.WORKOUTS_COMPLETED,
        timestamp,
    )
    await _refresh_metric_quests_from_history(
        db,
        submission_user_id,
        QuestMetric.ACTIVE_MINUTES,
        timestamp,
    )
    await _refresh_workout_quests(
        db,
        submission_user_id,
        completed_at=completion_ts,
        now=timestamp,
    )
    await db.commit()


async def claim_user_quest(
    db: AsyncSession,
    user_id: UUID,
    quest_id: UUID,
    *,
    now: datetime | None = None,
) -> UserQuest:
    timestamp = now or _utc_now()
    result = await db.execute(
        select(UserQuest)
        .options(selectinload(UserQuest.template))
        .where(
            and_(
                UserQuest.id == quest_id,
                UserQuest.user_id == user_id,
            )
        )
    )
    quest = result.scalars().first()
    if quest is None:
        raise NoResultFound("quest not found")

    await _sync_quests(db, [quest], timestamp)
    if quest.status == QuestStatus.CLAIMED.value:
        return quest
    if quest.status != QuestStatus.COMPLETED.value:
        raise ValueError("quest is not completed")

    template = quest.template
    if template is None:
        await db.refresh(quest, attribute_names=["template"])
        template = quest.template
    if template is None:
        raise RuntimeError("quest template missing")

    await _claim_reward(db, quest, template, timestamp)
    return quest


__all__ = [
    "QuestCadence",
    "QuestMetric",
    "QuestStatus",
    "QuestTemplate",
    "UserQuest",
    "get_user_quests",
    "process_routine_submission_event",
    "claim_user_quest",
]
