from app.models.score import Score
from app.schemas.score import ScoreCreate
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select


async def create_score(db: AsyncSession, score_data: ScoreCreate) -> Score:
    score = Score(
        user_id=score_data.user_id,
        scenario_id=score_data.scenario_id,
        weight_lifted=score_data.weight_lifted,
    )
    db.add(score)
    await db.commit()
    await db.refresh(score)
    return score
