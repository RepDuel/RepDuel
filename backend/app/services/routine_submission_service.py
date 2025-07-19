# backend/app/services/routine_submission_service.py

from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.routine_submission import RoutineSubmission, RoutineScenarioSubmission
from app.models.routine import Routine
from app.models.user import User
from app.schemas.routine_submission import RoutineSubmissionCreate
from datetime import datetime


async def get_user_submissions(db: AsyncSession, user_id: str) -> List[RoutineSubmission]:
    result = await db.execute(
        select(RoutineSubmission).where(RoutineSubmission.user_id == user_id)
    )
    return result.scalars().all()


async def create_routine_submission(
    db: AsyncSession,
    routine_submission_data: RoutineSubmissionCreate,
    current_user: User,
) -> RoutineSubmission:
    # Check if the routine exists
    routine_result = await db.execute(
        select(Routine).where(Routine.id == routine_submission_data.routine_id)
    )
    routine = routine_result.scalar_one_or_none()
    if not routine:
        raise ValueError("Routine not found.")

    # Create the new routine submission record
    routine_submission = RoutineSubmission(
        routine_id=routine_submission_data.routine_id,
        user_id=current_user.id,
        duration=routine_submission_data.duration,
        completion_timestamp=routine_submission_data.completion_timestamp,
        status=routine_submission_data.status,
    )

    # Add associated scenario submissions
    for scenario in routine_submission_data.scenarios:
        scenario_submission = RoutineScenarioSubmission(
            scenario_id=scenario.scenario_id,
            sets=scenario.sets,
            reps=scenario.reps,
            weight=scenario.weight,
            total_volume=scenario.total_volume,
        )
        routine_submission.scenario_submissions.append(scenario_submission)

    # Save to database
    db.add(routine_submission)
    await db.commit()
    await db.refresh(routine_submission)
    return routine_submission
