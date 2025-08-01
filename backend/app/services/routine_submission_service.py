# backend/app/services/routine_submission_service.py


from datetime import datetime
from typing import List

from app.models.routine import Routine
from app.models.routine_submission import RoutineScenarioSubmission, RoutineSubmission
from app.models.user import User
from app.schemas.routine_submission import RoutineSubmissionCreate
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from fastapi import HTTPException, status


async def get_user_submissions(
    db: AsyncSession, user_id: str
) -> List[RoutineSubmission]:
    result = await db.execute(
        select(RoutineSubmission).where(RoutineSubmission.user_id == user_id)
    )
    return result.scalars().all()


def generate_strava_title(scenarios: List[dict], timestamp: datetime) -> str:
    """
    Generates a Strava-style workout title using time of day and the first trained muscle group.
    """
    hour = timestamp.hour
    if 5 <= hour < 12:
        time_label = "Morning"
    elif 12 <= hour < 17:
        time_label = "Afternoon"
    elif 17 <= hour < 21:
        time_label = "Evening"
    else:
        time_label = "Night"

    for scenario in scenarios:
        muscles = getattr(scenario, "primary_muscles", None)
        if muscles and isinstance(muscles, list) and muscles:
            return f"{time_label} {muscles[0]} Workout"

    return f"{time_label} Workout"


async def create_routine_submission(
    db: AsyncSession,
    routine_submission_data: RoutineSubmissionCreate,
    current_user: User,
) -> RoutineSubmission:
    # Enforce paywall: limit free users to 3 custom routine submissions
    if current_user.subscription_level == "free":
        existing_submissions = await db.execute(
            select(RoutineSubmission)
            .where(RoutineSubmission.user_id == current_user.id)
        )
        if len(existing_submissions.scalars().all()) >= 3:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Upgrade required to submit more than 3 custom routines."
            )

    # Check if the routine exists
    routine_result = await db.execute(
        select(Routine).where(Routine.id == routine_submission_data.routine_id)
    )
    routine = routine_result.scalar_one_or_none()
    if not routine:
        raise ValueError("Routine not found.")

    title = generate_strava_title(
        routine_submission_data.scenarios,
        routine_submission_data.completion_timestamp or datetime.utcnow()
    )

    routine_submission = RoutineSubmission(
        routine_id=routine_submission_data.routine_id,
        user_id=current_user.id,
        duration=routine_submission_data.duration,
        completion_timestamp=routine_submission_data.completion_timestamp,
        status=routine_submission_data.status,
        title=title,
    )

    for scenario in routine_submission_data.scenarios:
        scenario_submission = RoutineScenarioSubmission(
            scenario_id=scenario.scenario_id,
            sets=scenario.sets,
            reps=scenario.reps,
            weight=scenario.weight,
            total_volume=scenario.total_volume,
        )
        routine_submission.scenario_submissions.append(scenario_submission)

    db.add(routine_submission)
    await db.commit()
    await db.refresh(routine_submission)
    return routine_submission
