# backend/app/api/v1/energy.py

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.models.energy_history import EnergyHistory
from app.models.user import User
from app.schemas.energy import (
    DailyEnergyEntry,
    EnergyEntry,
    EnergyLeaderboardEntry,
    EnergySubmit,
)

router = APIRouter(
    prefix="/energy",
    tags=["Energy"],
)

def _rank_from_energy(energy: float) -> str:
    thresholds = [
        (1200, "Celestial"),
        (1100, "Astra"),
        (1000, "Nova"),
        (900, "Grandmaster"),
        (800, "Master"),
        (700, "Jade"),
        (600, "Diamond"),
        (500, "Platinum"),
        (400, "Gold"),
        (300, "Silver"),
        (200, "Bronze"),
        (100, "Iron"),
    ]
    for threshold, rank in thresholds:
        if energy >= threshold:
            return rank
    return "Unranked"


@router.post("/submit")
async def submit_energy(data: EnergySubmit, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.id == data.user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    user.energy = data.energy
    user.rank = data.rank
    db.add(user)

    entry = EnergyHistory(user_id=data.user_id, energy=data.energy)
    db.add(entry)

    await db.commit()

    return {"message": "Energy and rank updated successfully"}


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
    stmt = select(User).where(User.is_active == True)
    result = await db.execute(stmt)
    users = result.scalars().all()

    users.sort(
        key=lambda u: (
            -(u.energy or 0),
            u.updated_at if isinstance(u.updated_at, datetime) else datetime.min,
        )
    )

    entries = []
    for index, user in enumerate(users, start=1):
        total_energy = int(round(user.energy or 0))
        final_rank = _rank_from_energy(total_energy)
        entries.append(
            EnergyLeaderboardEntry(
                rank=index,
                user_id=user.id,
                username=user.username,
                display_name=user.display_name,
                avatar_url=user.avatar_url,
                total_energy=total_energy,
                user_rank=final_rank,
            )
        )

    return entries


@router.get("/daily/{user_id}", response_model=list[DailyEnergyEntry])
async def get_energy_by_day(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = (
        select(
            func.date(EnergyHistory.created_at).label("date"),
            func.max(EnergyHistory.energy).label("total_energy"),
        )
        .where(EnergyHistory.user_id == user_id)
        .group_by(func.date(EnergyHistory.created_at))
        .order_by(func.date(EnergyHistory.created_at))
    )
    result = await db.execute(stmt)
    return [
        DailyEnergyEntry(date=row.date, total_energy=row.total_energy) for row in result
    ]


@router.get("/latest/{user_id}", response_model=int)
async def get_latest_energy(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(User.energy).where(User.id == user_id)
    result = await db.execute(stmt)
    energy = result.scalar_one_or_none()

    if energy is None:
        return 0
    return int(energy)
