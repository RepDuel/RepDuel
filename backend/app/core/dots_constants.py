# backend/app/core/dots_constants.py

from typing import Dict

DOTS_RANKS: Dict[str, int] = {
    "Iron": 120,
    "Bronze": 150,
    "Silver": 180,
    "Gold": 210,
    "Platinum": 240,
    "Diamond": 270,
    "Jade": 300,
    "Master": 330,
    "Grandmaster": 360,
    "Nova": 400,
    "Astra": 450,
    "Celestial": 500,
}

LIFT_RATIOS: Dict[str, float] = {
    "squat": 0.33,
    "bench": 0.25,
    "deadlift": 0.42,
}

RANK_METADATA: Dict[str, Dict] = {}
