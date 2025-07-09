from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from app.api.v1.deps import get_db
from app.models.energy_history import EnergyHistory
from app.schemas.energy import EnergyEntry
from sqlalchemy.future import select

router = APIRouter()

@router.get("/energy/history/{user_id}", response_model=list[EnergyEntry])
async def get_energy_history(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(EnergyHistory).where(EnergyHistory.user_id == user_id).order_by(EnergyHistory.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()
