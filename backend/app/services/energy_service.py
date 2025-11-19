# backend/app/services/energy_service.py

from typing import Tuple
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import user as user_models
from app.models.energy_history import EnergyHistory
from app.models.score import Score
from app.services.dots_service import DotsCalculator
from app.services.standards_service import LB_PER_KG, get_rounded_pack
from app.services.user_service import get_user_by_id

SCENARIO_LIFT_MAP = {
    "back_squat": "squat",
    "barbell_bench_press": "bench",
    "deadlift": "deadlift",
}

RANK_ORDER = [
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

RANK_ENERGY = {
    "Unranked": 0,
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


def interpolate_energy(
    score: float, lower: float, upper: float, lower_energy: int, upper_energy: int
) -> float:
    if upper == lower:
        return upper_energy
    ratio = (score - lower) / (upper - lower)
    return lower_energy + ratio * (upper_energy - lower_energy)


def compute_energy_for_lift(score: float, lift: str, standards: dict) -> int:
    """
    Interpolate energy for a single lift given a score and a standards pack.

    NOTE: The `standards` pack must be in the SAME UNIT as `score`.
    """
    for i in range(len(RANK_ORDER) - 1):
        lower_rank = RANK_ORDER[i]
        upper_rank = RANK_ORDER[i + 1]
        lower_val = standards[lower_rank]["lifts"].get(lift, 0)
        upper_val = standards[upper_rank]["lifts"].get(lift, 0)

        if lower_val <= score < upper_val:
            return round(
                interpolate_energy(
                    score,
                    lower_val,
                    upper_val,
                    RANK_ENERGY[lower_rank],
                    RANK_ENERGY[upper_rank],
                )
            )

    celestial = standards["Celestial"]["lifts"].get(lift, 0)
    astra = standards["Astra"]["lifts"].get(lift, 0)
    if score >= celestial and celestial > astra:
        extra = (score - celestial) / (celestial - astra)
        return round(1200 + extra * 100)

    iron_val = standards["Iron"]["lifts"].get(lift, 1)
    if score < iron_val and iron_val > 0:
        return round((score / iron_val) * 100)

    return 0


def _overall_rank_from_energy(avg_energy: float) -> str:
    # Choose the highest rank whose floor is <= avg_energy
    for rank in reversed(RANK_ORDER):
        if avg_energy >= RANK_ENERGY[rank]:
            return rank
    return "Unranked"


async def update_energy_if_personal_best(
    db: AsyncSession,
    user_id: UUID,
    scenario_id: str,
    new_score: float,
    is_bodyweight: bool = False,
):
    """
    Called on score creation. If this is a personal best for the scenario,
    recompute energy using the user's preferred unit pack and append to history.

    `new_score` is the 1RM-equivalent (or reps for bodyweight) stored in KG.
    """
    scenario_id_str = str(scenario_id)
    lift = SCENARIO_LIFT_MAP.get(scenario_id_str)
    if not lift:
        return

    user = await get_user_by_id(db, user_id)
    if not user:
        return

    gender = (user.gender or "male").lower()
    if gender not in ["male", "female"]:
        gender = "male"

    bodyweight_kg = user.weight or 70.0

    # Check if this is a personal best for this scenario (scores are stored in kg)
    stmt = (
        select(Score)
        .where(Score.user_id == user_id, Score.scenario_id == scenario_id)
        .order_by(Score.score_value.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    best = result.scalar_one_or_none()

    if best and new_score <= best.score_value:
        return

    # Build standards pack in user's preferred unit
    preferred_unit = getattr(user, "preferred_unit", "kg")
    standards = await get_rounded_pack(
        bodyweight=bodyweight_kg if preferred_unit == "kg" else bodyweight_kg,
        gender=gender,
        unit=preferred_unit,
    )

    # Convert score to user's unit for comparison
    score_in_user_unit = new_score * (LB_PER_KG if preferred_unit == "lbs" else 1.0)
    energy = compute_energy_for_lift(score_in_user_unit, lift, standards)

    db_entry = EnergyHistory(user_id=user_id, energy=energy)
    db.add(db_entry)
    await db.commit()


async def recompute_for_user(
    current_user: user_models.User,
    _new_unit: str,
    db: AsyncSession,
) -> Tuple[float, str]:
    """
    Recompute user's overall energy & rank using their CURRENT preferred_unit,
    based on best scores per core lift (scores are stored in kg).

    Returns (energy, rank).
    """
    gender = (current_user.gender or "male").lower()
    if gender not in ("male", "female"):
        gender = "male"

    bodyweight_kg = current_user.weight or 70.0
    unit = getattr(current_user, "preferred_unit", "kg")

    # Get best score (kg) per scenario
    best_scores_kg: dict[str, float] = {}
    for scenario_id in SCENARIO_LIFT_MAP.keys():
        stmt = (
            select(func.max(Score.score_value))
            .where(Score.user_id == current_user.id, Score.scenario_id == scenario_id)
        )
        max_val = (await db.execute(stmt)).scalar_one_or_none()
        if max_val is not None:
            best_scores_kg[scenario_id] = float(max_val)

    if not best_scores_kg:
        current_user.energy = 0.0
        current_user.rank = "Unranked"
        db.add(current_user)
        await db.commit()
        await db.refresh(current_user)
        return current_user.energy, current_user.rank or "Unranked"

    # Standards pack in user's preferred unit
    standards = await get_rounded_pack(
        bodyweight=bodyweight_kg if unit == "kg" else bodyweight_kg,
        gender=gender,
        unit=unit,
    )

    # Compute energy per lift in user's unit
    per_lift_energies = []
    for scenario_id, kg_val in best_scores_kg.items():
        lift_key = SCENARIO_LIFT_MAP[scenario_id]
        score_in_user_unit = kg_val * (LB_PER_KG if unit == "lbs" else 1.0)
        e = compute_energy_for_lift(score_in_user_unit, lift_key, standards)
        per_lift_energies.append(e)

    avg_energy = sum(per_lift_energies) / len(per_lift_energies)
    rounded = round(avg_energy)
    overall = _overall_rank_from_energy(rounded)

    current_user.energy = float(rounded)
    current_user.rank = overall
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user.energy, current_user.rank or "Unranked"
