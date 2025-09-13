# backend/app/services/standards_service.py

from typing import Dict, Literal

from app.services.dots_service import compute_standards_exact_kg, round_to_nearest_5

KG_PER_LB = 0.45359237
LB_PER_KG = 2.2046226218


def to_lbs(kg: float) -> float:
    return kg * LB_PER_KG


def to_kg(lbs: float) -> float:
    return lbs * KG_PER_LB


def round5_int(x: float) -> int:
    return int(round_to_nearest_5(x))


def _compute_pack_sync(
    *,
    bodyweight: float,
    gender: str,
    unit: Literal["kg", "lbs"]
) -> Dict[str, Dict]:
    bodyweight_kg = bodyweight if unit == "kg" else to_kg(bodyweight)
    exact = compute_standards_exact_kg(bodyweight_kg, gender)
    pack: Dict[str, Dict] = {}

    if unit == "kg":
        for rank, data in exact.items():
            pack[rank] = {
                "total": round5_int(data["total"]),
                "lifts": {
                    "squat": round5_int(data["lifts"]["squat"]),
                    "bench": round5_int(data["lifts"]["bench"]),
                    "deadlift": round5_int(data["lifts"]["deadlift"]),
                },
                "metadata": data.get("metadata", {}),
            }
        return pack

    for rank, data in exact.items():
        pack[rank] = {
            "total": round5_int(to_lbs(data["total"])),
            "lifts": {
                "squat": round5_int(to_lbs(data["lifts"]["squat"])),
                "bench": round5_int(to_lbs(data["lifts"]["bench"])),
                "deadlift": round5_int(to_lbs(data["lifts"]["deadlift"])),
            },
            "metadata": data.get("metadata", {}),
        }
    return pack


async def get_rounded_pack(
    *,
    bodyweight: float,
    gender: str,
    unit: Literal["kg", "lbs"]
) -> Dict[str, Dict]:
    # Async wrapper so callers can `await` this function.
    return _compute_pack_sync(bodyweight=bodyweight, gender=gender, unit=unit)
