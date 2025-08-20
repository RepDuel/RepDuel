from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import get_db
from app.core.auth import get_current_user
from app.models.routine_submission import RoutineSubmission
from app.models.user import User
from app.schemas.routine_submission import (RoutineSubmissionCreate,
                                            RoutineSubmissionRead)
from app.services.routine_submission_service import create_routine_submission

router = APIRouter(prefix="/routine_submission", tags=["routine_submission"])


@router.post(
    "/", response_model=RoutineSubmissionRead, status_code=status.HTTP_201_CREATED
)
async def submit_routine(
    routine_submission_data: RoutineSubmissionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        submission = await create_routine_submission(
            db, routine_submission_data, current_user
        )
        await db.refresh(submission)

        result = await db.execute(
            select(RoutineSubmission)
            .options(selectinload(RoutineSubmission.scenario_submissions))
            .where(RoutineSubmission.id == submission.id)
        )
        loaded = result.scalars().first()
        return RoutineSubmissionRead.model_validate(loaded)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/user/{user_id}", response_model=List[RoutineSubmissionRead])
async def get_user_routine_history(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(RoutineSubmission)
        .options(selectinload(RoutineSubmission.scenario_submissions))
        .where(RoutineSubmission.user_id == user_id)
    )
    submissions = result.scalars().all()
    return [RoutineSubmissionRead.model_validate(sub) for sub in submissions]
