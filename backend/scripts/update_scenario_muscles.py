"""Update scenario muscle associations using OpenAI classification.

This script connects to the configured PostgreSQL database, retrieves all
scenarios, classifies their primary and secondary muscles with OpenAI, and
updates the scenario/muscle association tables using the SQLAlchemy ORM.

Usage:
    python -m scripts.update_scenario_muscles [--dry-run]

Environment:
    - DATABASE_URL must be set (defaults to the app's env configuration).
    - OPENAI_API_KEY must be set for the OpenAI Python SDK.
    - Optionally OPENAI_MODEL can override the default classification model.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
from dataclasses import dataclass
from typing import Iterable, List, Sequence

from openai import OpenAI
from sqlalchemy import create_engine, select
from sqlalchemy.engine import URL, make_url
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

import app.db.base  # noqa: F401 - ensure all model mappers are configured
from app.core.config import settings
from app.models.muscle import Muscle
from app.models.scenario import Scenario
from app.models.bodyweight_calibration import (  # noqa: F401 - ensure mapper configuration
    BodyweightCalibration,
)
from app.models.personal_best_event import (  # noqa: F401 - ensure mapper configuration
    PersonalBestEvent,
)
from app.models.score import Score  # noqa: F401 - ensure mapper configuration
from app.models.user import User  # noqa: F401 - ensure mapper configuration

ALLOWED_MUSCLES = {
    "abs",
    "biceps",
    "calves",
    "chest",
    "forearms",
    "glutes",
    "hamstrings",
    "lats",
    "lower back",
    "quads",
    "shoulders",
    "traps",
    "triceps",
}

DEFAULT_OPENAI_MODEL = "gpt-5"
SYSTEM_PROMPT = (
    "You assign primary and secondary muscles for workout scenarios. "
    "Only use the allowed muscles: "
    + ", ".join(sorted(ALLOWED_MUSCLES))
    + ". Return strict JSON with keys 'primary' and 'secondary', each an array. "
    "Primary muscles should contain the main movers (1-3 entries). Secondary "
    "muscles should list supporting groups (0-4 entries). Never repeat a muscle "
    "or overlap between primary and secondary. Use lowercase muscle names."
)

logger = logging.getLogger(__name__)


class ProgressBar:
    def __init__(self, total: int, width: int = 30) -> None:
        self.total = total
        self.current = 0
        self.width = max(10, width)

    def update(self, advance: int = 0, message: str | None = None) -> None:
        self.current += advance
        message = (message or "")[:40]
        if self.total <= 0:
            sys.stdout.write(f"\rProcessed {self.current} {message:40}")
            sys.stdout.flush()
            return

        fraction = min(1.0, self.current / self.total)
        filled = int(self.width * fraction)
        bar = "#" * filled + "-" * (self.width - filled)
        percentage = fraction * 100.0
        sys.stdout.write(
            f"\r[{bar}] {self.current:>4}/{self.total:<4} {percentage:6.2f}% {message:40}"
        )
        sys.stdout.flush()

    def finish(self, message: str | None = None, *, complete: bool = True) -> None:
        if self.total > 0 and complete and self.current < self.total:
            self.update(self.total - self.current, message)
        else:
            self.update(0, message)
        sys.stdout.write("\n")
        sys.stdout.flush()


def configure_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def make_sync_engine() -> "Engine":
    url: URL = make_url(str(settings.DATABASE_URL))
    if "+asyncpg" in url.drivername:
        url = url.set(drivername=url.drivername.replace("+asyncpg", ""))
    return create_engine(url, future=True)


def normalise_muscles(muscles: Iterable[str]) -> List[str]:
    seen = set()
    cleaned: List[str] = []
    for name in muscles:
        candidate = name.strip().lower()
        if not candidate or candidate in seen or candidate not in ALLOWED_MUSCLES:
            continue
        seen.add(candidate)
        cleaned.append(candidate)
    return cleaned


@dataclass
class ClassifiedMuscles:
    primary: List[str]
    secondary: List[str]

    @classmethod
    def empty(cls) -> "ClassifiedMuscles":
        return cls(primary=[], secondary=[])

    def ensure_disjoint(self) -> None:
        primary_set = set(self.primary)
        self.secondary = [m for m in self.secondary if m not in primary_set]


class ScenarioClassifier:
    def __init__(self, model: str | None = None, max_retries: int = 3, delay: float = 2.0):
        self.client = OpenAI()
        self.model = model or DEFAULT_OPENAI_MODEL
        self.max_retries = max_retries
        self.delay = delay

    def classify(self, name: str, description: str | None) -> ClassifiedMuscles:
        prompt = (
            f"Scenario name: {name}\n"
            f"Description: {description or 'No description provided.'}\n\n"
            "Respond with JSON specifying the primary and secondary muscles."
        )
        for attempt in range(1, self.max_retries + 1):
            try:
                completion = self.client.chat.completions.create(
                    model=self.model,
                    temperature=0,
                    response_format={"type": "json_object"},
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": prompt},
                    ],
                )
                content = completion.choices[0].message.content
                data = json.loads(content)
                primary = normalise_muscles(data.get("primary", []))
                secondary = normalise_muscles(data.get("secondary", []))
                muscles = ClassifiedMuscles(primary=primary, secondary=secondary)
                muscles.ensure_disjoint()
                return muscles
            except Exception as exc:  # noqa: BLE001
                logger.warning(
                    "OpenAI classification failed (attempt %s/%s): %s",
                    attempt,
                    self.max_retries,
                    exc,
                )
                if attempt == self.max_retries:
                    break
                time.sleep(self.delay)
        return ClassifiedMuscles.empty()


def fetch_muscle_lookup(session: Session) -> dict[str, Muscle]:
    muscles = session.execute(select(Muscle)).scalars().all()
    lookup: dict[str, Muscle] = {}
    for muscle in muscles:
        keys = {
            muscle.name.strip().lower(),
            muscle.id.strip().lower().replace("_", " "),
        }
        for key in keys:
            if key:
                lookup.setdefault(key, muscle)

    missing = ALLOWED_MUSCLES - set(lookup)
    if missing:
        logger.warning("Missing muscles in database: %s", ", ".join(sorted(missing)))
    return lookup


def update_scenario_muscles(session: Session, classifier: ScenarioClassifier, dry_run: bool) -> None:
    lookup = fetch_muscle_lookup(session)
    scenarios: Sequence[Scenario] = session.execute(select(Scenario)).scalars().all()
    total = len(scenarios)
    logger.info("Processing %s scenarios", total)

    progress = ProgressBar(total)
    updated = 0
    skipped = 0
    failures = 0

    try:
        for scenario in scenarios:
            muscles = classifier.classify(scenario.name, scenario.description)
            if not muscles.primary and not muscles.secondary:
                logger.debug("Skipping scenario %s – no classification result", scenario.name)
                skipped += 1
                progress.update(1, f"{scenario.name} skipped")
                continue

            primary_objs = [lookup[m] for m in muscles.primary if m in lookup]
            secondary_objs = [lookup[m] for m in muscles.secondary if m in lookup]

            logger.debug(
                "Scenario %s: primary=%s secondary=%s",
                scenario.id,
                [m.name for m in primary_objs],
                [m.name for m in secondary_objs],
            )

            scenario.primary_muscles = primary_objs
            scenario.secondary_muscles = secondary_objs
            try:
                if dry_run:
                    session.flush()
                else:
                    session.commit()
                updated += 1
                progress.update(1, f"{scenario.name} updated")
            except SQLAlchemyError as exc:
                failures += 1
                session.rollback()
                progress.update(1, f"{scenario.name} error")
                logger.error("Failed to persist scenario %s: %s", scenario.id, exc)
    except KeyboardInterrupt:
        progress.finish("interrupted", complete=False)
        session.rollback()
        logger.warning(
            "Interrupted by user (updated=%s, skipped=%s, errors=%s)",
            updated,
            skipped,
            failures,
        )
        raise SystemExit(1)

    if dry_run:
        session.rollback()
        progress.finish("dry run complete")
        logger.info(
            "Dry run complete – rolled back changes (updated=%s, skipped=%s, errors=%s)",
            updated,
            skipped,
            failures,
        )
    else:
        progress.finish("done")
        logger.info(
            "Database updated successfully (updated=%s, skipped=%s, errors=%s)",
            updated,
            skipped,
            failures,
        )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Update scenario muscle associations.")
    parser.add_argument("--dry-run", action="store_true", help="Run without committing changes")
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging")
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Override the OpenAI model to use for classification",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    configure_logging(verbose=args.verbose)

    engine = make_sync_engine()
    SessionLocal = sessionmaker(bind=engine, expire_on_commit=False, future=True)
    classifier = ScenarioClassifier(model=args.model)

    with SessionLocal() as session:
        update_scenario_muscles(session, classifier, dry_run=args.dry_run)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
