# backend/app/api/v1/scenario.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import get_db
from app.models.scenario import Scenario
from app.schemas.scenario import ScenarioCreate, ScenarioOut, ScenarioRead

router = APIRouter(prefix="/scenarios", tags=["Scenarios"])


@router.get("/", response_model=list[ScenarioOut])
async def list_scenarios(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Scenario))
    scenarios = result.scalars().all()
    return scenarios


@router.post("/", response_model=ScenarioOut)
async def create_scenario(scenario: ScenarioCreate, db: AsyncSession = Depends(get_db)):
    db_scenario = Scenario(**scenario.model_dump())
    db.add(db_scenario)
    await db.commit()
    await db.refresh(db_scenario)
    return db_scenario


@router.get("/{scenario_id}/multiplier", response_model=float)
async def get_scenario_multiplier(scenario_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Scenario).filter(Scenario.id == scenario_id))
    scenario = result.scalars().first()

    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    return scenario.multiplier


@router.get("/{scenario_id}/details", response_model=ScenarioRead)
async def get_scenario_details(scenario_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Scenario)
        .options(
            selectinload(Scenario.primary_muscles),
            selectinload(Scenario.secondary_muscles),
            selectinload(Scenario.equipment),
            selectinload(Scenario.calibration),
        )
        .filter(Scenario.id == scenario_id)
    )
    scenario = result.scalars().first()

    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    return ScenarioRead(
        id=scenario.id,
        name=scenario.name,
        description=scenario.description,
        multiplier=scenario.multiplier,
        volume_multiplier=scenario.volume_multiplier,
        is_bodyweight=scenario.is_bodyweight,
        primary_muscles=[muscle.name for muscle in scenario.primary_muscles],
        secondary_muscles=[muscle.name for muscle in scenario.secondary_muscles],
        equipment=[item.name for item in scenario.equipment],
        calibration=scenario.calibration,
    )
