# backend/app/services/dots_service.py

from typing import Dict, Optional

from app.core.dots_constants import (DOTS_RANKS,
                                     LIFT_RATIOS, RANK_METADATA)


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
            coefficient = 500 / (-0.000001093 * bodyweight_kg**4 + 
                                0.0007391293 * bodyweight_kg**3 - 
                                0.1918759221 * bodyweight_kg**2 + 
                                24.0900756 * bodyweight_kg - 
                                307.75076)
        
        elif gender == "female":
            coefficient = 500 / (-0.0000010706 * bodyweight_kg**4 + 
                                0.0005158568 * bodyweight_kg**3 - 
                                0.1126655495 * bodyweight_kg**2 + 
                                13.6175032 * bodyweight_kg - 
                                57.96288)
        
        else:
            raise ValueError("Gender must be either 'male' or 'female'")
        
        return coefficient

    @staticmethod
    def calculate_lift_standards(bodyweight_kg: float, gender: str, lift_ratio: float) -> Dict:
        """Calculate lift standards for all ranks"""
        standards = {}
        coeff = DotsCalculator.get_coefficient(bodyweight_kg, gender)

        for rank, dots in DOTS_RANKS.items():
            total_kg = dots / coeff
            lift_value = total_kg * lift_ratio  # Total weight * lift_ratio for each rank
            
            standards[rank] = lift_value  # Store rank with corresponding lift value

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
        next_rank_threshold = -1  # Will be set to the next rank threshold or -1 if max rank reached
        max_rank = "Celestial"

        # Find current rank based on the user's lift score (e.g., squat score)
        for i, (rank, lift_value) in enumerate(standards.items()):
            if user_lift_score >= lift_value:
                current_rank = rank
                if i + 1 < len(standards):
                    next_rank_threshold = list(standards.values())[i + 1]  # Get the next rank's threshold
                break
        
        # If the user reached the "Celestial" rank
        if current_rank == max_rank:
            next_rank_threshold = -1  # No next rank available

        return {
            "current_rank": current_rank,
            "next_rank_threshold": next_rank_threshold,
        }