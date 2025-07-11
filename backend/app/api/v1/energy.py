# backend/app/api/v1/energy.py

from uuid import UUID

from app.api.v1.deps import get_db
from app.models.energy_history import EnergyHistory
from app.models.user import User
from app.schemas.energy import (EnergyEntry, EnergyLeaderboardEntry,
                                EnergySubmit)
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(
    prefix="/energy",
    tags=["Energy"],
)


@router.post("/submit")
async def submit_energy(data: EnergySubmit, db: AsyncSession = Depends(get_db)):
    # Verify user exists
    stmt = select(User).where(User.id == data.user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    # Create new energy entry
    entry = EnergyHistory(user_id=data.user_id, energy=data.energy)
    db.add(entry)
    await db.commit()
    return {"message": "Energy submitted successfully"}


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
    # Subquery to get latest energy per user
    subquery = (
        select(
            EnergyHistory.user_id, func.max(EnergyHistory.created_at).label("latest")
        )
        .group_by(EnergyHistory.user_id)
        .subquery()
    )

    stmt = (
        select(
            User.id.label("user_id"),
            User.username,
            EnergyHistory.energy.label("total_energy"),
        )
        .join(EnergyHistory, User.id == EnergyHistory.user_id)
        .join(
            subquery,
            (EnergyHistory.user_id == subquery.c.user_id)
            & (EnergyHistory.created_at == subquery.c.latest),
        )
        .order_by(EnergyHistory.energy.desc())
    )

    result = await db.execute(stmt)
    rows = result.all()

    leaderboard = [
        EnergyLeaderboardEntry(
            rank=index,
            user_id=row.user_id,
            username=row.username,
            total_energy=row.total_energy,
        )
        for index, row in enumerate(rows, start=1)
    ]

    return leaderboard
