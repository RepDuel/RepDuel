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


# -------------------------------
# POST /energy/submit
# Submit a new energy record
# -------------------------------
@router.post("/submit")
async def submit_energy(data: EnergySubmit, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.id == data.user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    entry = EnergyHistory(user_id=data.user_id, energy=data.energy)
    db.add(entry)
    await db.commit()

    return {"message": "Energy submitted successfully"}


# -------------------------------
# GET /energy/history/{user_id}
# Full energy history (recent first)
# -------------------------------
@router.get("/history/{user_id}", response_model=list[EnergyEntry])
async def get_energy_history(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = (
        select(EnergyHistory)
        .where(EnergyHistory.user_id == user_id)
        .order_by(EnergyHistory.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


# -------------------------------
# GET /energy/leaderboard
# Latest energy entry per user
# -------------------------------
@router.get("/leaderboard", response_model=list[EnergyLeaderboardEntry])
async def get_energy_leaderboard(db: AsyncSession = Depends(get_db)):
    # Subquery to get latest entry timestamp per user
    subquery = (
        select(
            EnergyHistory.user_id,
            func.max(EnergyHistory.created_at).label("latest"),
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

    return [
        EnergyLeaderboardEntry(
            rank=index,
            user_id=row.user_id,
            username=row.username,
            total_energy=row.total_energy,
        )
        for index, row in enumerate(rows, start=1)
    ]


# -------------------------------
# GET /energy/daily/{user_id}
# Daily peak (max) energy for graphing
# -------------------------------
@router.get("/daily/{user_id}", response_model=list[DailyEnergyEntry])
async def get_energy_by_day(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = (
        select(
            func.date(EnergyHistory.created_at).label("date"),
            func.max(EnergyHistory.energy).label(
                "total_energy"
            ),  # ✅ changed from sum to max
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
    stmt = (
        select(EnergyHistory)
        .where(EnergyHistory.user_id == user_id)
        .order_by(EnergyHistory.created_at.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    latest = result.scalar_one_or_none()

    if latest is None:
        raise HTTPException(status_code=404, detail="No energy record found")
    return latest.energy
