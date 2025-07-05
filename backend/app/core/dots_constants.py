# backend/app/core/dots_constants.py

from typing import Dict, List, Tuple

# DOTs Ranking System
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
    "Celestial": 500
}

# Lift percentage of total for balanced lifters
LIFT_RATIOS: Dict[str, float] = {
    "squat": 0.33,
    "bench": 0.25,
    "deadlift": 0.42
}

# DOTs coefficients by bodyweight (kg)
DOTS_COEFFICIENTS: Dict[str, float] = {
    # Male coefficients
    "male": {
        "60.0": 0.78,   # ~132 lbs
        "70.0": 0.72,   # ~154 lbs
        "80.0": 0.67,   # ~176 lbs
        "90.7": 0.62,   # 200 lbs
        "100.0": 0.58,  # ~220 lbs
        "110.0": 0.55,  # ~242 lbs
        "120.0": 0.52   # ~264 lbs
    },
    # Female coefficients
    "female": {
        "50.0": 0.82,   # ~110 lbs
        "60.0": 0.75,   # ~132 lbs
        "70.0": 0.69,   # ~154 lbs
        "80.0": 0.64,   # ~176 lbs
        "90.0": 0.60    # ~198 lbs
    }
}

# Rank metadata (colors, icons, etc.)
RANK_METADATA: Dict[str, Dict] = {
    "Iron": {"color": "#a19d94", "description": "Beginner"},
    "Bronze": {"color": "#cd7f32", "description": "Novice"},
    # ... add other rank metadata
}