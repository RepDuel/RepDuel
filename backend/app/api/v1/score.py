# backend/app/api/v1/score.py

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import get_db
from app.models.score import Score
from app.schemas.score import ScoreCreate, ScoreOut, ScoreReadWithUser
from app.services.energy_service import update_energy_if_personal_best

router = APIRouter(prefix="/scores", tags=["Scores"])

# Helper function to calculate score_value (same formula as Dart)
def calculate_score_value(weight_lifted: float, reps: int | None) -> float:
    if reps is None or reps == 1:
        return weight_lifted
    return weight_lifted * (1 + reps / 30)


@router.post("/", response_model=ScoreOut)
async def create_score(
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
):
    # Calculate score_value before creating the record
    score_value = calculate_score_value(score.weight_lifted, score.reps)
    db_score = Score(**score.dict(), score_value=score_value)  # Add calculated score_value
    db.add(db_score)
    await db.commit()
    await db.refresh(db_score)
    return db_score


@router.post("/scenario/{scenario_id}/", response_model=ScoreOut)
async def create_score_for_scenario(
    scenario_id: str,
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
):
    # Calculate score_value
    score_value = calculate_score_value(score.weight_lifted, score.reps)
    score_data = score.dict()
    score_data["scenario_id"] = scenario_id
    
    db_score = Score(**score_data, score_value=score_value)  # Add calculated score_value
    db.add(db_score)
    await db.commit()
    await db.refresh(db_score)

    # 🔥 Update energy if it's a new PR - now using score_value instead of weight_lifted
    await update_energy_if_personal_best(
        user_id=score.user_id,
        scenario_id=scenario_id,
        new_score=score_value,  # Use score_value instead of weight_lifted
        db=db,
    )

    return db_score


@router.get(
    "/scenario/{scenario_id}/leaderboard", response_model=list[ScoreReadWithUser]
)
async def get_leaderboard(
    scenario_id: str,
    db: AsyncSession = Depends(get_db),
):
    subquery = (
        select(Score.user_id, func.max(Score.score_value).label("max_score"))  # Use score_value
        .where(Score.scenario_id == scenario_id)
        .group_by(Score.user_id)
        .subquery()
    )

    stmt = (
        select(Score)
        .options(selectinload(Score.user))
        .join(
            subquery,
            (Score.user_id == subquery.c.user_id)
            & (Score.score_value == subquery.c.max_score),  # Use score_value
        )
        .where(Score.scenario_id == scenario_id)
        .order_by(Score.score_value.desc())  # Use score_value
    )

    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/user/{user_id}/scenario/{scenario_id}", response_model=list[ScoreOut])
async def get_user_score_history(
    user_id: UUID,
    scenario_id: str,
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Score)
        .where(Score.user_id == user_id, Score.scenario_id == scenario_id)
        .order_by(Score.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/user/{user_id}/scenario/{scenario_id}/highscore", response_model=ScoreOut)
async def get_user_high_score(
    user_id: UUID,
    scenario_id: str,
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Score)
        .where(Score.user_id == user_id, Score.scenario_id == scenario_id)
        .order_by(Score.score_value.desc())  # Use score_value instead of weight_lifted
        .limit(1)
    )
    result = await db.execute(stmt)
    score = result.scalar_one_or_none()

    if score is None:
        raise HTTPException(
            status_code=404, detail="No score found for this user and scenario"
        )

    return score


@router.delete("/user/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_all_user_scores(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Score).where(Score.user_id == user_id)
    result = await db.execute(stmt)
    user_scores = result.scalars().all()

    if not user_scores:
        raise HTTPException(status_code=404, detail="No scores found for this user")

    for score in user_scores:
        await db.delete(score)

    await db.commit()