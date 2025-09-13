# backend/app/services/rank_service.py

import os

from fastapi import HTTPException


def get_rank_from_energy(energy: float) -> str:
    if energy >= 1200:
        return "Celestial"
    if energy >= 1100:
        return "Astra"
    if energy >= 1000:
        return "Nova"
    if energy >= 900:
        return "Grandmaster"
    if energy >= 800:
        return "Master"
    if energy >= 700:
        return "Jade"
    if energy >= 600:
        return "Diamond"
    if energy >= 500:
        return "Platinum"
    if energy >= 400:
        return "Gold"
    if energy >= 300:
        return "Silver"
    if energy >= 200:
        return "Bronze"
    return "Iron"


def get_rank_color(rank: str) -> str:
    rank_colors = {
        "Iron": "#808080",
        "Bronze": "#cd7f32",
        "Silver": "#c0c0c0",
        "Gold": "#efbf04",
        "Platinum": "#00ced1",
        "Diamond": "#b9f2ff",
        "Jade": "#62f40c",
        "Master": "#ff00ff",
        "Grandmaster": "#ffde21",
        "Nova": "#a45ee5",
        "Astra": "#ff4040",
        "Celestial": "#00ffff",
    }
    return rank_colors.get(rank, "#FFFFFF")


def get_rank_icon_path(rank: str) -> str:
    icon_path = "assets/images/ranks/"
    icon_files = {
        "Iron": "iron.svg",
        "Bronze": "bronze.svg",
        "Silver": "silver.svg",
        "Gold": "gold.svg",
        "Platinum": "platinum.svg",
        "Diamond": "diamond.svg",
        "Jade": "jade.svg",
        "Master": "master.svg",
        "Grandmaster": "grandmaster.svg",
        "Nova": "nova.svg",
        "Astra": "astra.svg",
        "Celestial": "celestial.svg",
    }

    icon_file = icon_files.get(rank)
    if icon_file:
        return os.path.join(icon_path, icon_file)
    raise HTTPException(status_code=400, detail=f"Invalid rank: {rank}")
