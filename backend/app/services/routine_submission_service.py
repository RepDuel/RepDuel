from sqlalchemy.ext.asyncio import AsyncSession
from app.models.routine_submission import RoutineSubmission, RoutineScenarioSubmission
from app.schemas.routine_submission import RoutineSubmissionCreate
from app.models.routine import Routine
from app.models.user import User
from datetime import datetime

async def create_routine_submission(db: AsyncSession, routine_submission_data: RoutineSubmissionCreate, current_user: User):
    # Check if the routine exists
    routine = await db.execute(Routine.query.filter(Routine.id == routine_submission_data.routine_id).first())
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

    # Add scenarios for the submission
    scenarios = [
        RoutineScenarioSubmission(
            scenario_id=scenario.scenario_id,
            sets=scenario.sets,
            reps=scenario.reps,
            weight=scenario.weight,
            total_volume=scenario.total_volume
        )
        for scenario in routine_submission_data.scenarios
    ]

    routine_submission.scenarios.extend(scenarios)

    # Save the routine submission
    db.add(routine_submission)
    await db.commit()
    return routine_submission
