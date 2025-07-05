# backend/app/services/dots_service.py

from typing import Dict, Optional
from app.core.dots_constants import DOTS_RANKS, LIFT_RATIOS, DOTS_COEFFICIENTS, RANK_METADATA

class DotsCalculator:
    @staticmethod
    def get_coefficient(bodyweight_kg: float, gender: str = "male") -> float:
        """Get DOTs coefficient for given bodyweight and gender"""
        gender_coeffs = DOTS_COEFFICIENTS.get(gender, DOTS_COEFFICIENTS["male"])
        closest_weight = min(
            gender_coeffs.keys(),
            key=lambda x: abs(float(x) - bodyweight_kg)
        )
        return gender_coeffs[closest_weight]

    @staticmethod
    def calculate_dots(total_kg: float, bodyweight_kg: float, gender: str = "male") -> float:
        """Calculate DOTs score with gender support"""
        coeff = DotsCalculator.get_coefficient(bodyweight_kg, gender)
        return round(total_kg * coeff, 2)

    @staticmethod
    def get_rank(dots_score: float) -> Dict:
        """Get rank with metadata"""
        rank_name = "Iron"
        for rank, threshold in sorted(DOTS_RANKS.items(), key=lambda x: x[1], reverse=True):
            if dots_score >= threshold:
                rank_name = rank
                break
        
        return {
            "name": rank_name,
            **RANK_METADATA.get(rank_name, {}),
            "next_rank": DotsCalculator.get_next_rank(rank_name),
            "dots_required": DOTS_RANKS[rank_name]
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
                    **RANK_METADATA.get(next_rank[0], {})
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
            standards[rank] = {
                "total": round(total_kg, 1),
                "lifts": {
                    "squat": round(total_kg * LIFT_RATIOS["squat"], 1),
                    "bench": round(total_kg * LIFT_RATIOS["bench"], 1),
                    "deadlift": round(total_kg * LIFT_RATIOS["deadlift"], 1)
                },
                "metadata": RANK_METADATA.get(rank, {})
            }
            
        return standards