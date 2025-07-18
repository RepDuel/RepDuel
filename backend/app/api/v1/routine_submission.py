from fastapi import APIRouter, Depends, HTTPException
from app.services.routine_submission_service import create_routine_submission
from app.models.routine_submission import RoutineSubmission
from app.schemas.routine_submission import RoutineSubmissionCreate
from app.db.base_class import Base
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from app.api.v1.deps import get_db
from app.models.user import User
from fastapi import status
from app.core.auth import get_current_user

router = APIRouter(prefix="/routine_submission", tags=["routine_submission"])

@router.post("/", response_model=RoutineSubmission, status_code=status.HTTP_201_CREATED)
async def submit_routine(
    routine_submission_data: RoutineSubmissionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return await create_routine_submission(db, routine_submission_data, current_user)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
