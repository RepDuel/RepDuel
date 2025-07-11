# app/api/v1/scenario.py

from app.api.v1.deps import get_db
from app.models.scenario import Scenario
from app.schemas.scenario import ScenarioCreate, ScenarioOut
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/scenarios", tags=["Scenarios"])


@router.get("/", response_model=list[ScenarioOut])
async def list_scenarios(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Scenario))
    scenarios = result.scalars().all()
    return scenarios


@router.post("/", response_model=ScenarioOut)
async def create_scenario(scenario: ScenarioCreate, db: AsyncSession = Depends(get_db)):
    db_scenario = Scenario(**scenario.dict())
    db.add(db_scenario)
    await db.commit()
    await db.refresh(db_scenario)
    return db_scenario
