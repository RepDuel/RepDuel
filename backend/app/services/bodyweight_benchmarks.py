# backend/app/services/bodyweight_benchmarks.py

"""Benchmark generation for bodyweight scenarios.

The calibration table stores five anchors that describe expected performance
for two reference bodyweights (50 kg and 140 kg) plus an intermediate check at
95 kg.  Using those anchors we infer the full rank curve for any bodyweight by
blending the beginner ↔ elite curves and solving for the Jade (intermediate)
anchor.

This module exposes a single helper, ``generate_bodyweight_benchmarks``, which
accepts either a SQLAlchemy model instance or a plain dictionary so it can be
re-used in tests or offline scripts.
"""

from __future__ import annotations

from typing import Any, Dict, Union

# Order used across the app (matches frontend rank/energy map)
RANKS_ORDER = [
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


def _as_value(obj: Union[Any, Dict[str, Any]], key: str) -> float:
    """Return a calibration value regardless of backing container type."""

    if hasattr(obj, key):
        return float(getattr(obj, key))
    return float(obj[key])


def generate_bodyweight_benchmarks(
    calibration: Union[Any, Dict[str, Any]],
    bodyweight_kg: float,
) -> Dict[str, int]:
    """Generate per-rank thresholds for a bodyweight exercise.

    Calibration anchors:

    * ``beginner_50`` / ``elite_50`` at 50 kg
    * ``beginner_140`` / ``elite_140`` at 140 kg
    * ``intermediate_95`` pins the Jade rank at 95 kg

    The beginner and elite curves are interpolated linearly between the anchor
    bodyweights.  We then solve for the blend factor (``alpha``) that makes the
    Jade rank land on ``intermediate_95``.  Ranks below Jade are spaced evenly
    between Beginner and Intermediate; ranks above Jade (up to Astra) are spaced
    between Intermediate and Elite.  Celestial extrapolates beyond Astra using
    the same step as Nova → Astra.
    """

    if bodyweight_kg <= 0:
        raise ValueError("bodyweight_kg must be positive")

    # ---- 1) Interpolate Beginner & Elite curves across BW ∈ [50, 140] ----
    t = (bodyweight_kg - 50.0) / 90.0
    t = max(0.0, min(1.0, t))

    b50 = _as_value(calibration, "beginner_50")
    e50 = _as_value(calibration, "elite_50")
    b140 = _as_value(calibration, "beginner_140")
    e140 = _as_value(calibration, "elite_140")
    inter95 = _as_value(calibration, "intermediate_95")

    beginner_bw = b50 + (b140 - b50) * t
    elite_bw = e50 + (e140 - e50) * t
    gap = elite_bw - beginner_bw

    # ---- 2) Solve blend alpha so that Jade@95 equals intermediate_95 ----
    t95 = (95.0 - 50.0) / 90.0
    beginner_95 = b50 + (b140 - b50) * t95
    elite_95 = e50 + (e140 - e50) * t95
    denom = elite_95 - beginner_95

    if abs(denom) < 1e-9:
        alpha = 0.6  # fallback if curves coincide at 95 kg
    else:
        alpha = (inter95 - beginner_95) / denom
        alpha = max(0.0, min(1.0, alpha))

    # ---- 3) Map ranks to fractions between Beginner (0) and Elite (1) ----
    low_ranks = [
        "Iron",
        "Bronze",
        "Silver",
        "Gold",
        "Platinum",
        "Diamond",
        "Jade",
    ]
    high_ranks = ["Master", "Grandmaster", "Nova", "Astra"]

    steps_low = len(low_ranks) - 1
    steps_high = len(high_ranks) - 1

    fractions: Dict[str, float] = {}

    if steps_low <= 0:
        for rank in low_ranks:
            fractions[rank] = alpha
        fractions["Iron"] = 0.0
    else:
        for idx, rank in enumerate(low_ranks):
            fractions[rank] = alpha * (idx / steps_low)

    if steps_high <= 0:
        for rank in high_ranks:
            fractions[rank] = 1.0
    else:
        denom = len(high_ranks)
        for idx, rank in enumerate(high_ranks, start=1):
            fractions[rank] = alpha + (1.0 - alpha) * (idx / denom)

    # ---- 4) Convert to absolute values (exclude Celestial for now) ----
    thresholds: Dict[str, int] = {}
    for rank in RANKS_ORDER:
        if rank == "Celestial":
            continue
        fraction = fractions[rank]
        value = beginner_bw + fraction * gap
        thresholds[rank] = int(round(value))

    # ---- 5) Celestial uses the same step size as Nova → Astra ----
    astra_val = thresholds["Astra"]
    nova_val = thresholds["Nova"]
    step = astra_val - nova_val
    thresholds["Celestial"] = int(round(astra_val + step))

    return thresholds
