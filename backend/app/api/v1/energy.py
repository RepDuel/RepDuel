from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import UUID

from app.api.v1.deps import get_db
from app.models.energy_history import EnergyHistory
from app.models.user import User
from app.schemas.energy import EnergyEntry, EnergyLeaderboardEntry

router = APIRouter(
    prefix="/energy",
    tags=["Energy"],
)


@router.get("/history/{user_id}", response_model=list[EnergyEntry])
async def get_energy_history(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = (
        select(EnergyHistory)
        .where(EnergyHistory.user_id == user_id)
        .order_by(EnergyHistory.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/leaderboard", response_model=list[EnergyLeaderboardEntry])
async def get_energy_leaderboard(db: AsyncSession = Depends(get_db)):
    stmt = (
        select(
            User.id.label("user_id"),
            User.username,
            func.sum(EnergyHistory.energy).label("total_energy")
        )
        .join(EnergyHistory, User.id == EnergyHistory.user_id)
        .group_by(User.id, User.username)
        .order_by(func.sum(EnergyHistory.energy).desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    # Add ranks
    leaderboard = []
    for index, row in enumerate(rows, start=1):
        leaderboard.append({
            "rank": index,
            "user_id": row.user_id,
            "username": row.username,
            "total_energy": row.total_energy
        })

    return leaderboard
