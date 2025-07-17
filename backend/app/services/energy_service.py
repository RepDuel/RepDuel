# app/services/energy_service.py

import math
from uuid import UUID

from app.models.energy_history import EnergyHistory
from app.services.dots_service import DotsCalculator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Hardcoded mapping for each scenario to the corresponding lift name
SCENARIO_LIFT_MAP = {
    "back_squat": "squat",
    "barbell_bench_press": "bench",
    "deadlift": "deadlift",
}


# Get the latest energy entry for a user
async def get_latest_energy(db: AsyncSession, user_id: UUID) -> float:
    stmt = (
        select(EnergyHistory)
        .where(EnergyHistory.user_id == user_id)
        .order_by(EnergyHistory.created_at.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    latest = result.scalar_one_or_none()
    return latest.energy if latest else 0.0


# Interpolate energy between two ranks
def interpolate_energy(
    score: float, lower: float, upper: float, lower_energy: int, upper_energy: int
) -> float:
    if upper == lower:
        return upper_energy
    ratio = (score - lower) / (upper - lower)
    return lower_energy + ratio * (upper_energy - lower_energy)


# Main logic to compute energy for a lift
def compute_energy_for_lift(score: float, lift: str, standards: dict) -> int:
    rank_order = [
        "Iron",
        "Bronze",
        "Silver",
        "Gold",
        "Platinum",
        "Diamond",
        "Jade",
        "Master",
        "Grandmaster",
        "Nova",
        "Astra",
        "Celestial",
    ]
    rank_energy = {
        "Iron": 100,
        "Bronze": 200,
        "Silver": 300,
        "Gold": 400,
        "Platinum": 500,
        "Diamond": 600,
        "Jade": 700,
        "Master": 800,
        "Grandmaster": 900,
        "Nova": 1000,
        "Astra": 1100,
        "Celestial": 1200,
    }

    for i in range(len(rank_order) - 1):
        lower_rank = rank_order[i]
        upper_rank = rank_order[i + 1]
        lower_val = standards[lower_rank]["lifts"].get(lift, 0)
        upper_val = standards[upper_rank]["lifts"].get(lift, 0)

        if lower_val <= score < upper_val:
            return round(
                interpolate_energy(
                    score,
                    lower_val,
                    upper_val,
                    rank_energy[lower_rank],
                    rank_energy[upper_rank],
                )
            )

    # Above Celestial
    celestial = standards["Celestial"]["lifts"].get(lift, 0)
    astra = standards["Astra"]["lifts"].get(lift, 0)
    if score >= celestial and celestial > astra:
        extra = (score - celestial) / (celestial - astra)
        return round(1200 + extra * 100)

    # Below Iron
    iron_val = standards["Iron"]["lifts"].get(lift, 1)
    if score < iron_val and iron_val > 0:
        return round((score / iron_val) * 100)

    return 0


# Public method to compute and store energy
async def update_energy_if_personal_best(
    db: AsyncSession,
    user_id: UUID,
    scenario_id: UUID,
    new_score: float,
    bodyweight_kg: float,
    gender: str,
):
    scenario_id_str = str(scenario_id)
    lift = SCENARIO_LIFT_MAP.get(scenario_id_str)
    if not lift:
        return

    # Fetch user's current personal best for that scenario
    from app.models.score import Score

    stmt = (
        select(Score)
        .where(Score.user_id == user_id, Score.scenario_id == scenario_id)
        .order_by(Score.weight_lifted.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    best = result.scalar_one_or_none()

    if best and new_score <= best.weight_lifted:
        return  # Not a new PR

    # Fetch standards and compute energy
    standards = DotsCalculator.get_lift_standards(bodyweight_kg, gender)
    energy = compute_energy_for_lift(new_score, lift, standards)

    db_entry = EnergyHistory(user_id=user_id, energy=energy)
    db.add(db_entry)
    await db.commit()
