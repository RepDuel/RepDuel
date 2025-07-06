from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, select
from uuid import UUID

from app.api.v1.deps import get_db
from app.models.score import Score
from app.models.scenario import Scenario
from app.schemas.score import ScoreCreate, ScoreOut

router = APIRouter(prefix="/scores", tags=["Scores"])


@router.post("/", response_model=ScoreOut)
async def create_score(
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
):
    db_score = Score(**score.dict())
    db.add(db_score)
    await db.commit()
    await db.refresh(db_score)
    return db_score


@router.post("/scenario/{scenario_id}/", response_model=ScoreOut)
async def create_score_for_scenario(
    scenario_id: UUID,
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
):
    score_data = score.dict()
    score_data["scenario_id"] = scenario_id

    db_score = Score(**score_data)
    db.add(db_score)
    await db.commit()
    await db.refresh(db_score)
    return db_score


@router.get("/scenario/{scenario_id}/leaderboard", response_model=list[ScoreOut])
async def get_leaderboard(
    scenario_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    subquery = (
        select(
            Score.user_id,
            func.max(Score.weight_lifted).label("max_weight")
        )
        .where(Score.scenario_id == scenario_id)
        .group_by(Score.user_id)
        .subquery()
    )

    stmt = (
        select(Score)
        .join(
            subquery,
            (Score.user_id == subquery.c.user_id) &
            (Score.weight_lifted == subquery.c.max_weight)
        )
        .where(Score.scenario_id == scenario_id)
        .order_by(Score.weight_lifted.desc())
    )

    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/user/{user_id}/scenario/{scenario_id}", response_model=list[ScoreOut])
async def get_user_score_history(
    user_id: UUID,
    scenario_id: UUID,
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
    scenario_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Score)
        .where(Score.user_id == user_id, Score.scenario_id == scenario_id)
        .order_by(Score.weight_lifted.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    score = result.scalar_one_or_none()

    if score is None:
        raise HTTPException(status_code=404, detail="No score found for this user and scenario")

    return score
