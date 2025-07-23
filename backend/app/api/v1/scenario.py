# backend/app/api/v1/scenario.py

from app.api.v1.deps import get_db
from app.models.scenario import Scenario
from app.schemas.scenario import ScenarioCreate, ScenarioOut, ScenarioRead
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
    db_scenario = Scenario(**scenario.model_dump())
    db.add(db_scenario)
    await db.commit()
    await db.refresh(db_scenario)
    return db_scenario


@router.get("/{scenario_id}/multiplier", response_model=float)
async def get_scenario_multiplier(scenario_id: str, db: AsyncSession = Depends(get_db)):
    # Query the database for the scenario by id
    result = await db.execute(select(Scenario).filter(Scenario.id == scenario_id))
    scenario = result.scalars().first()

    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    # Return the multiplier of the found scenario
    return scenario.multiplier

@router.get("/{scenario_id}/details", response_model=ScenarioRead)
async def get_scenario_details(scenario_id: str, db: AsyncSession = Depends(get_db)):
    # Query the database for the scenario by id
    result = await db.execute(select(Scenario).filter(Scenario.id == scenario_id))
    scenario = result.scalars().first()

    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")

    # Construct and return the ScenarioRead model
    scenario_read = ScenarioRead(
        id=scenario.id,
        name=scenario.name,
        description=scenario.description,
        multiplier=scenario.multiplier,
        primary_muscles=scenario.primary_muscles,
        secondary_muscles=scenario.secondary_muscles,
        equipment=scenario.equipment
    )
    
    return scenario_read