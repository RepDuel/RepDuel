# backend/app/api/v1/energy.py

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.models.energy_history import EnergyHistory
from app.models.user import User
from app.schemas.energy import (DailyEnergyEntry, EnergyEntry,
                                EnergyLeaderboardEntry, EnergySubmit)

router = APIRouter(
    prefix="/energy",
    tags=["Energy"],
)


@router.post("/submit")
async def submit_energy(data: EnergySubmit, db: AsyncSession = Depends(get_db)):
    """
    Submits a new energy score for a user. This endpoint creates a historical
    record and also updates the user's main record with the latest energy and rank.
    """
    stmt = select(User).where(User.id == data.user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    # Update the user's main record with the new energy and rank
    user.energy = data.energy
    user.rank = data.rank
    db.add(user) # Add the updated user object to the session

    # Create a new entry in the energy history table for tracking progress
    entry = EnergyHistory(user_id=data.user_id, energy=data.energy)
    db.add(entry)
    
    # Commit both changes (user update and history creation) in one transaction
    await db.commit()

    return {"message": "Energy and rank updated successfully"}


@router.get("/history/{user_id}", response_model=list[EnergyEntry])
async def get_energy_history(user_id: UUID, db: AsyncSession = Depends(get_db)):
    """
    Retrieves the full energy history for a given user, ordered from newest to oldest.
    """
    stmt = (
        select(EnergyHistory)
        .where(EnergyHistory.user_id == user_id)
        .order_by(EnergyHistory.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/leaderboard", response_model=list[EnergyLeaderboardEntry])
async def get_energy_leaderboard(db: AsyncSession = Depends(get_db)):
    """
    Retrieves the global energy leaderboard.
    It shows each user's latest and highest official energy score.
    """
    # This query directly uses the `energy` and `rank` from the `User` table,
    # which is efficient and accurate.
    stmt = (
        select(
            User.id.label("user_id"),
            User.username,
            User.avatar_url,
            User.energy.label("total_energy"),
            User.rank.label("user_rank"),
        )
        .where(User.is_active == True)
        .order_by(User.energy.desc().nullslast(), User.updated_at.asc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    return [
        EnergyLeaderboardEntry(
            rank=index + 1,
            user_id=row.user_id,
            username=row.username,
            avatar_url=row.avatar_url,
            total_energy=row.total_energy or 0,
            user_rank=row.user_rank or "Unranked",
        )
        for index, row in enumerate(rows)
    ]


@router.get("/daily/{user_id}", response_model=list[DailyEnergyEntry])
async def get_energy_by_day(user_id: UUID, db: AsyncSession = Depends(get_db)):
    """
    Retrieves the peak (max) energy score for each day for a given user.
    Used for building the progress graph.
    """
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
    """
    Retrieves the user's latest official energy score.
    Reads directly from the user's record for maximum efficiency.
    """
    stmt = select(User.energy).where(User.id == user_id)
    result = await db.execute(stmt)
    energy = result.scalar_one_or_none()

    if energy is None:
        return 0
    return int(energy)