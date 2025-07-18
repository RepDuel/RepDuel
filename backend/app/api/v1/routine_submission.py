from fastapi import APIRouter, Depends, HTTPException, status
from app.services.routine_submission_service import create_routine_submission
from app.schemas.routine_submission import RoutineSubmissionCreate, RoutineSubmissionRead
from app.db.base_class import Base
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.v1.deps import get_db
from app.models.user import User
from app.core.auth import get_current_user

router = APIRouter(prefix="/routine_submission", tags=["routine_submission"])

@router.post("/", response_model=RoutineSubmissionRead, status_code=status.HTTP_201_CREATED)
async def submit_routine(
    routine_submission_data: RoutineSubmissionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        # Create routine submission and return the Pydantic response model
        routine_submission = await create_routine_submission(db, routine_submission_data, current_user)
        return routine_submission
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
