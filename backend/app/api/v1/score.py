# backend/app/api/v1/score.py

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import get_db
from app.models.score import Score
from app.models.personal_best_event import PersonalBestEvent
from app.models.scenario import Scenario
from app.models.user import User
from app.schemas.score import (
    ScoreCreate,
    ScoreCreateResponse,
    ScoreOut,
    ScoreReadWithUser,
)
from app.services.energy_service import update_energy_if_personal_best

router = APIRouter(prefix="/scores", tags=["Scores"])


def calculate_score_value(weight_lifted: float, reps: int | None, is_bodyweight: bool = False) -> float:
    if is_bodyweight:
        return reps if reps is not None else 0
    if reps is None or reps == 1:
        return weight_lifted
    return weight_lifted * (1 + reps / 30)


@router.post("/", response_model=ScoreOut)
async def create_score(
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
):
    score_value = calculate_score_value(score.weight_lifted, score.reps)
    db_score = Score(**score.dict(), score_value=score_value)
    db.add(db_score)
    await db.commit()
    await db.refresh(db_score)
    return db_score


@router.post("/scenario/{scenario_id}/", response_model=ScoreCreateResponse)
async def create_score_for_scenario(
    scenario_id: str,
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
):
    scenario = await db.get(Scenario, scenario_id)
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    is_bodyweight = scenario.is_bodyweight

    previous_best_stmt = (
        select(Score)
        .where(Score.user_id == score.user_id, Score.scenario_id == scenario_id)
        .order_by(Score.score_value.desc())
        .limit(1)
    )
    previous_best_result = await db.execute(previous_best_stmt)
    previous_best = previous_best_result.scalar_one_or_none()

    score_value = calculate_score_value(
        score.weight_lifted,
        score.reps,
        is_bodyweight=is_bodyweight,
    )

    db_score = Score(
        user_id=score.user_id,
        scenario_id=scenario_id,
        weight_lifted=score.weight_lifted,
        reps=score.reps,
        sets=score.sets,
        score_value=score_value,
        is_bodyweight=is_bodyweight,
    )

    is_personal_best = (
        previous_best is None or score_value > previous_best.score_value
    )

    db.add(db_score)

    if is_personal_best:
        db.add(
            PersonalBestEvent(
                user_id=score.user_id,
                scenario_id=scenario_id,
                score_value=score_value,
                weight_lifted=score.weight_lifted,
                reps=score.reps,
                is_bodyweight=is_bodyweight,
            )
        )

    await db.commit()
    await db.refresh(db_score)

    await update_energy_if_personal_best(
        db=db,
        user_id=score.user_id,
        scenario_id=scenario_id,
        new_score=score_value,
    )

    return ScoreCreateResponse(
        score=ScoreOut.model_validate(db_score),
        is_personal_best=is_personal_best,
        previous_best_score_value=(
            previous_best.score_value if previous_best is not None else None
        ),
        previous_best_weight_lifted=(
            previous_best.weight_lifted if previous_best is not None else None
        ),
        previous_best_reps=previous_best.reps if previous_best is not None else None,
        previous_best_sets=previous_best.sets if previous_best is not None else None,
    )


@router.get(
    "/scenario/{scenario_id}/leaderboard", response_model=list[ScoreReadWithUser]
)
async def get_leaderboard(
    scenario_id: str,
    db: AsyncSession = Depends(get_db),
):
    subquery = (
        select(Score.user_id, func.max(Score.score_value).label("max_score"))
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
            & (Score.score_value == subquery.c.max_score),
        )
        .where(Score.scenario_id == scenario_id)
        .order_by(Score.score_value.desc())
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
        .order_by(Score.score_value.desc())
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
