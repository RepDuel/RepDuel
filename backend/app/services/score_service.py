# backend/app/services/score_service.py
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.score import Score
from app.schemas.score import ScoreCreate


def calculate_score_value(
    weight_lifted: float, reps: int | None, *, is_bodyweight: bool = False
) -> float:
    if is_bodyweight:
        return float(reps or 0)
    if reps is None or reps == 1:
        return weight_lifted
    return weight_lifted * (1 + reps / 30)


async def create_score(
    db: AsyncSession,
    *,
    user_id: UUID,
    scenario_id: str,
    score_data: ScoreCreate,
    score_value: float,
    is_bodyweight: bool,
) -> Score:
    """Create and persist a score row."""

    score = Score(
        user_id=user_id,
        scenario_id=scenario_id,
        weight_lifted=score_data.weight_lifted,
        reps=score_data.reps,
        sets=score_data.sets,
        score_value=score_value,
        is_bodyweight=is_bodyweight,
    )
    db.add(score)
    await db.commit()
    await db.refresh(score)
    return score
