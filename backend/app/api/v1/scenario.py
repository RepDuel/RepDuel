# app/api/v1/scenario.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api.v1.deps import get_db
from app.models.scenario import Scenario
from app.schemas.scenario import ScenarioCreate, ScenarioOut

router = APIRouter(prefix="/scenarios", tags=["Scenarios"])

@router.get("/", response_model=list[ScenarioOut])
def list_scenarios(db: Session = Depends(get_db)):
    return db.query(Scenario).all()

@router.post("/", response_model=ScenarioOut)
def create_scenario(scenario: ScenarioCreate, db: Session = Depends(get_db)):
    db_scenario = Scenario(**scenario.dict())
    db.add(db_scenario)
    db.commit()
    db.refresh(db_scenario)
    return db_scenario
