# backend/seed/seed_scenarios_copy.py
import csv
import re
import asyncio
from pathlib import Path
from typing import Dict, List

from sqlalchemy import text
from app.db.session import async_session

# ---- Config ----
TSV_PATH = Path(__file__).with_name("scenarios_copy.tsv")
TABLE = "scenarios_copy"  # target table

def slugify(name: str) -> str:
    slug = name.lower()
    slug = re.sub(r"[^a-z0-9]+", "_", slug)
    return slug.strip("_")

def coerce_bool(x) -> bool:
    if x is None:
        return False
    s = str(x).strip().lower()
    return s in ("1", "true", "t", "yes", "y")

def coerce_float(x, default: float = 1.0) -> float:
    try:
        return float(x)
    except (TypeError, ValueError):
        return default

def load_rows(tsv_path: Path) -> List[Dict]:
    rows: List[Dict] = []
    with tsv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        required = {"id", "name", "description", "is_bodyweight", "multiplier", "volume_multiplier"}
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"TSV is missing columns: {sorted(missing)}")

        for r in reader:
            name = (r.get("name") or "").strip()
            if not name:
                continue

            # Ensure id is a proper slug; if not, regenerate from name
            rid = (r.get("id") or "").strip()
            expected = slugify(name)
            if rid != expected:
                rid = expected  # enforce slug format

            rows.append({
                "id": rid,
                "name": name,
                "description": (r.get("description") or "").strip(),
                "is_bodyweight": coerce_bool(r.get("is_bodyweight")),
                "multiplier": coerce_float(r.get("multiplier"), 1.0),
                "volume_multiplier": coerce_float(r.get("volume_multiplier"), 1.0),
            })
    return rows

async def amain() -> None:
    if not TSV_PATH.exists():
        raise FileNotFoundError(f"TSV not found: {TSV_PATH}")

    data = load_rows(TSV_PATH)
    if not data:
        print("No rows to insert.")
        return

    async with async_session() as db:
        # Upsert by slug ID (deterministic, lowercase_with_underscores)
        stmt = text(f"""
            INSERT INTO {TABLE} (id, name, description, is_bodyweight, multiplier, volume_multiplier)
            VALUES (:id, :name, :description, :is_bodyweight, :multiplier, :volume_multiplier)
            ON CONFLICT (id) DO UPDATE
            SET name = EXCLUDED.name,
                description = EXCLUDED.description,
                is_bodyweight = EXCLUDED.is_bodyweight,
                multiplier = EXCLUDED.multiplier,
                volume_multiplier = EXCLUDED.volume_multiplier
        """)

        # executemany: pass a list[dict]
        await db.execute(stmt, data)
        await db.commit()
        print(f"Upserted {len(data)} rows into {TABLE}.")

if __name__ == "__main__":
    asyncio.run(amain())
