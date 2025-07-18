# backend/app/api/v1/routine_submission.py

from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base_class import Base
from app.models import RoutineSubmission, RoutineScenarioSubmission
from app.schemas.routine_submission import RoutineSubmissionCreate, RoutineSubmissionRead
from app.services import routine_submission_service
from app.api.v1.deps import get_db

router = APIRouter(prefix="/routine_submission", tags=["Routine Submission"])


@router.post("/", response_model=RoutineSubmissionRead)
async def submit_routine(
    routine_submission: RoutineSubmissionCreate,
    db: AsyncSession = Depends(get_db),
):
    # Submit the routine submission
    return await routine_submission_service.create_routine_submission(db, routine_submission)


@router.get("/{user_id}", response_model=List[RoutineSubmissionRead])
async def get_user_routine_submissions(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    # Fetch all routine submissions for a specific user
    return await routine_submission_service.get_user_routine_submissions(db, user_id)


@router.get("/{user_id}/history", response_model=List[RoutineSubmissionRead])
async def get_routine_submission_history(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    # Fetch routine submission history for a specific user
    return await routine_submission_service.get_routine_submission_history(db, user_id)


@router.put("/{routine_submission_id}", response_model=RoutineSubmissionRead)
async def update_routine_submission(
    routine_submission_id: UUID,
    updated_data: RoutineSubmissionCreate,
    db: AsyncSession = Depends(get_db),
):
    # Update a specific routine submission
    routine_submission = await routine_submission_service.get_routine_submission(
        db, routine_submission_id
    )
    if not routine_submission:
        raise HTTPException(status_code=404, detail="Routine Submission not found")

    return await routine_submission_service.update_routine_submission(
        db, routine_submission, updated_data
    )


@router.delete("/{routine_submission_id}", response_model=dict)
async def delete_routine_submission(
    routine_submission_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    # Delete a specific routine submission
    routine_submission = await routine_submission_service.get_routine_submission(
        db, routine_submission_id
    )
    if not routine_submission:
        raise HTTPException(status_code=404, detail="Routine Submission not found")

    await routine_submission_service.delete_routine_submission(db, routine_submission)
    return {"detail": "Routine Submission deleted"}
