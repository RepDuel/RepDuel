"""Timezone-handling helpers."""

from __future__ import annotations

from datetime import datetime, timezone

UTC = timezone.utc


def ensure_aware_utc(
    dt: datetime, *, field_name: str | None = None, allow_naive: bool = False
) -> datetime:
    """Return ``dt`` normalised to UTC, ensuring it carries timezone info.

    Args:
        dt: The datetime to normalise.
        field_name: Optional name of the field being validated, used in errors.

    Raises:
        ValueError: If ``dt`` is naïve and lacks timezone information and
            ``allow_naive`` is ``False``.
    """

    if dt.tzinfo is None:
        if allow_naive:
            return dt.replace(tzinfo=UTC)
        field = field_name or "datetime"
        raise ValueError(
            f"{field} must include timezone information (e.g. 'Z' or '+00:00')."
        )
    return dt.astimezone(UTC)


def ensure_optional_aware_utc(
    dt: datetime | None,
    *,
    field_name: str | None = None,
    allow_naive: bool = False,
) -> datetime | None:
    """Normalise an optional datetime to UTC, preserving ``None`` values."""

    if dt is None:
        return None
    return ensure_aware_utc(dt, field_name=field_name, allow_naive=allow_naive)


__all__ = ["ensure_aware_utc", "ensure_optional_aware_utc", "UTC"]
