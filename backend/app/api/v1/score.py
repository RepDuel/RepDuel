# backend/app/api/v1/score.py

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.auth import get_current_user
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
from app.services.level_service import award_xp
from app.services.score_service import calculate_score_value
from app.services.user_service import get_user_by_id

router = APIRouter(prefix="/scores", tags=["Scores"])


def _effective_multiplier(value: float | None) -> float:
    if value is None:
        return 1.0
    return value if value > 0 else 0.0


async def _award_volume_xp(
    db: AsyncSession,
    *,
    user_id: UUID,
    score_payload: ScoreCreate,
    scenario: Scenario,
    score_id: int,
) -> None:
    user = await get_user_by_id(db, user_id)
    if not user:
        return

    bodyweight = user.weight or 0
    if bodyweight <= 0:
        return

    load = score_payload.weight_lifted
    if load is None or load <= 0:
        if scenario.is_bodyweight:
            load = bodyweight
        else:
            return

    reps = score_payload.reps if score_payload.reps is not None else 1
    sets = score_payload.sets if score_payload.sets is not None else 1

    if reps <= 0 or sets <= 0:
        return

    total_volume = load * reps * sets * _effective_multiplier(scenario.volume_multiplier)
    if total_volume <= 0:
        return

    xp_amount = int(total_volume // bodyweight)
    if xp_amount <= 0:
        return

    await award_xp(
        db,
        user_id,
        xp_amount,
        reason=f"Volume from score {score_id}",
        source_type="score_volume",
        source_id=str(score_id),
    )


async def _award_personal_best_xp(
    db: AsyncSession,
    *,
    user_id: UUID,
    scenario: Scenario,
    score_id: int,
) -> None:
    scenario_label = scenario.name or scenario.id
    await award_xp(
        db,
        user_id,
        10,
        reason=f"Personal record for {scenario_label}",
        source_type="score_pr",
        source_id=str(score_id),
    )


async def _create_score_entry(
    db: AsyncSession,
    *,
    scenario: Scenario,
    payload: ScoreCreate,
    user_id: UUID,
) -> tuple[Score, bool, Score | None]:
    previous_best_stmt = (
        select(Score)
        .where(Score.user_id == user_id, Score.scenario_id == scenario.id)
        .order_by(Score.score_value.desc())
        .limit(1)
    )
    previous_best_result = await db.execute(previous_best_stmt)
    previous_best = previous_best_result.scalar_one_or_none()

    score_value = calculate_score_value(
        payload.weight_lifted,
        payload.reps,
        is_bodyweight=scenario.is_bodyweight,
    )

    db_score = Score(
        user_id=user_id,
        scenario_id=scenario.id,
        weight_lifted=payload.weight_lifted,
        reps=payload.reps,
        sets=payload.sets,
        score_value=score_value,
        is_bodyweight=scenario.is_bodyweight,
    )

    is_personal_best = (
        previous_best is None or score_value > previous_best.score_value
    )

    db.add(db_score)

    if is_personal_best:
        db.add(
            PersonalBestEvent(
                user_id=user_id,
                scenario_id=scenario.id,
                score_value=score_value,
                weight_lifted=payload.weight_lifted,
                reps=payload.reps,
                is_bodyweight=scenario.is_bodyweight,
            )
        )

    await db.commit()
    await db.refresh(db_score)

    await _award_volume_xp(
        db,
        user_id=user_id,
        score_payload=payload,
        scenario=scenario,
        score_id=db_score.id,
    )

    if is_personal_best:
        await _award_personal_best_xp(
            db,
            user_id=user_id,
            scenario=scenario,
            score_id=db_score.id,
        )

    await update_energy_if_personal_best(
        db=db,
        user_id=user_id,
        scenario_id=scenario.id,
        new_score=score_value,
    )

    return db_score, is_personal_best, previous_best


@router.post("/", response_model=ScoreOut)
async def create_score(
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not score.scenario_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="scenario_id is required",
        )

    scenario = await db.get(Scenario, score.scenario_id)
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    db_score, *_ = await _create_score_entry(
        db,
        scenario=scenario,
        payload=score,
        user_id=current_user.id,
    )

    return ScoreOut.model_validate(db_score)


@router.post("/scenario/{scenario_id}/", response_model=ScoreCreateResponse)
async def create_score_for_scenario(
    scenario_id: str,
    score: ScoreCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scenario = await db.get(Scenario, scenario_id)
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    if score.scenario_id and score.scenario_id != scenario_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="scenario_id in payload does not match path",
        )

    db_score, is_personal_best, previous_best = await _create_score_entry(
        db,
        scenario=scenario,
        payload=score,
        user_id=current_user.id,
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
    current_user: User = Depends(get_current_user),
):
    if current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    stmt = select(Score).where(Score.user_id == user_id)
    result = await db.execute(stmt)
    user_scores = result.scalars().all()

    if not user_scores:
        raise HTTPException(status_code=404, detail="No scores found for this user")

    for score in user_scores:
        await db.delete(score)

    await db.commit()
