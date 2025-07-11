from typing import Dict, Optional

from app.core.dots_constants import (DOTS_COEFFICIENTS, DOTS_RANKS,
                                     LIFT_RATIOS, RANK_METADATA)


def round_to_nearest_5(x: float) -> float:
    """Round value to the nearest 5."""
    return round(x / 5) * 5


class DotsCalculator:
    @staticmethod
    def get_coefficient(bodyweight_kg: float, gender: str = "male") -> float:
        """Get DOTs coefficient for given bodyweight and gender"""
        gender_coeffs = DOTS_COEFFICIENTS.get(gender, DOTS_COEFFICIENTS["male"])
        closest_weight = min(
            gender_coeffs.keys(), key=lambda x: abs(float(x) - bodyweight_kg)
        )
        return gender_coeffs[closest_weight]

    @staticmethod
    def calculate_dots(
        total_kg: float, bodyweight_kg: float, gender: str = "male"
    ) -> float:
        """Calculate DOTs score with gender support"""
        coeff = DotsCalculator.get_coefficient(bodyweight_kg, gender)
        return round(total_kg * coeff, 2)

    @staticmethod
    def get_rank(dots_score: float) -> Dict:
        """Get rank with metadata"""
        rank_name = "Iron"
        for rank, threshold in sorted(
            DOTS_RANKS.items(), key=lambda x: x[1], reverse=True
        ):
            if dots_score >= threshold:
                rank_name = rank
                break

        return {
            "name": rank_name,
            **RANK_METADATA.get(rank_name, {}),
            "next_rank": DotsCalculator.get_next_rank(rank_name),
            "dots_required": DOTS_RANKS[rank_name],
        }

    @staticmethod
    def get_next_rank(current_rank: str) -> Optional[Dict]:
        """Get next rank progression info"""
        ranks = list(DOTS_RANKS.items())
        try:
            current_index = [r[0] for r in ranks].index(current_rank)
            if current_index > 0:
                next_rank = ranks[current_index - 1]
                return {
                    "name": next_rank[0],
                    "dots_needed": next_rank[1] - DOTS_RANKS[current_rank],
                    **RANK_METADATA.get(next_rank[0], {}),
                }
        except ValueError:
            pass
        return None

    @staticmethod
    def get_lift_standards(bodyweight_kg: float, gender: str = "male") -> Dict:
        """Generate comprehensive standards"""
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
