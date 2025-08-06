from typing import Dict

import httpx

from app.core.config import settings
from app.core.dots_constants import DOTS_RANKS, LIFT_RATIOS, RANK_METADATA


def round_to_nearest_5(x: float) -> float:
    """Round value to the nearest 5."""
    return round(x / 5) * 5

def round_to_nearest_1(x: float) -> float:
    """Round value to the nearest 1."""
    return round(x)


class DotsCalculator:
    @staticmethod
    def get_coefficient(bodyweight_kg: float, gender: str = "male") -> float:
        """Get DOTs coefficient for given bodyweight and gender using polynomial function"""

        if gender == "male":
            return 500 / (
                -0.000001093 * bodyweight_kg**4
                + 0.0007391293 * bodyweight_kg**3
                - 0.1918759221 * bodyweight_kg**2
                + 24.0900756 * bodyweight_kg
                - 307.75076
            )

        elif gender == "female":
            return 500 / (
                -0.0000010706 * bodyweight_kg**4
                + 0.0005158568 * bodyweight_kg**3
                - 0.1126655495 * bodyweight_kg**2
                + 13.6175032 * bodyweight_kg
                - 57.96288
            )

        else:
            raise ValueError("Gender must be either 'male' or 'female'")

    @staticmethod
    def calculate_lift_standards(bodyweight_kg: float, gender: str, lift_ratio: float) -> Dict:
        """Calculate lift standards for all ranks"""
        standards = {}
        coeff = DotsCalculator.get_coefficient(bodyweight_kg, gender)

        for rank, dots in DOTS_RANKS.items():
            total_kg = dots / coeff
            lift_value = total_kg * lift_ratio
            standards[rank] = lift_value

        return standards

    @staticmethod
    def get_lift_standards(bodyweight_kg: float, gender: str = "male") -> Dict:
        """Generate comprehensive standards for all lifts (squat, bench, deadlift)"""
        standards = {}
        coeff = DotsCalculator.get_coefficient(bodyweight_kg, gender)

        for rank, dots in DOTS_RANKS.items():
            total_kg = dots / coeff
            squat = total_kg * LIFT_RATIOS["squat"]
            bench = total_kg * LIFT_RATIOS["bench"]
            deadlift = total_kg * LIFT_RATIOS["deadlift"]

            standards[rank] = {
                "total": round_to_nearest_5(total_kg),
                "lifts": {
                    "squat": round_to_nearest_5(squat),
                    "bench": round_to_nearest_5(bench),
                    "deadlift": round_to_nearest_5(deadlift),
                },
                "metadata": RANK_METADATA.get(rank, {}),
            }

        return standards

    @staticmethod
    def get_current_rank_and_next_rank(user_lift_score: float, standards: Dict) -> Dict:
        """Calculate current rank and next rank threshold based on user lift score"""
        current_rank = None
        next_rank_threshold = -1
        max_rank = "Celestial"

        # Sort standards from highest to lowest rank
        sorted_standards = sorted(standards.items(), key=lambda x: x[1], reverse=True)

        for i, (rank, lift_value) in enumerate(sorted_standards):
            if user_lift_score >= lift_value:
                current_rank = rank
                if i > 0:
                    next_rank_threshold = sorted_standards[i - 1][1]
                break

        if current_rank is None:
            current_rank = "Unranked"
            iron_standard = standards.get("Iron")
            if isinstance(iron_standard, dict):
                next_rank_threshold = iron_standard.get("total", -1)
            else:
                next_rank_threshold = iron_standard

        if current_rank == max_rank:
            next_rank_threshold = -1

        return {
            "current_rank": current_rank,
            "next_rank_threshold": next_rank_threshold,
        }

    @staticmethod
    async def get_rank_progress(
        scenario_id: str,
        final_score: float,
        user_weight: float,
        user_gender: str = "male",
    ) -> Dict:
        """Get current rank and next rank threshold for a user's lift score"""
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{settings.BASE_URL}/api/v1/scenarios/{scenario_id}/multiplier")

        if response.status_code != 200:
            raise ValueError("Failed to fetch scenario multiplier")

        data = response.json()
        scenario_multiplier = data.get("multiplier")
        if scenario_multiplier is None:
            raise ValueError("Multiplier not found in response")

        standards = DotsCalculator.calculate_lift_standards(
            bodyweight_kg=user_weight,
            gender=user_gender,
            lift_ratio=scenario_multiplier,
        )

        return DotsCalculator.get_current_rank_and_next_rank(
            user_lift_score=final_score,
            standards=standards,
        )
