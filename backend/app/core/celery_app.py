"""Celery application configuration for RepDuel.

This module prefers the real Celery implementation but falls back to a
lightweight in-memory runner when Celery is unavailable. The fallback keeps the
local development and test experience self-contained while preserving the task
API expected by the rest of the application.
"""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any, Callable, Iterable

try:  # pragma: no cover - exercised when Celery is installed
    from celery import Celery  # type: ignore
except ImportError:  # pragma: no cover - executed in environments without Celery
    class _Inspector:
        def stats(self) -> dict[str, dict[str, Any]]:
            return {"fallback": {}}

        def active(self) -> dict[str, list[Any]]:
            return {}

        def reserved(self) -> dict[str, list[Any]]:
            return {}

        def scheduled(self) -> dict[str, list[Any]]:
            return {}

    class _Control:
        def inspect(self, timeout: float | None = None) -> _Inspector:
            return _Inspector()

    class _TaskWrapper:
        def __init__(self, func: Callable[..., Any], *, bind: bool = False) -> None:
            self._func = func
            self._bind = bind

        def __call__(self, *args: Any, **kwargs: Any) -> Any:
            if self._bind:
                return self._func(self, *args, **kwargs)
            return self._func(*args, **kwargs)

        def delay(self, *args: Any, **kwargs: Any) -> Any:
            return self(*args, **kwargs)

    class Celery:  # type: ignore[override]
        class _Config(SimpleNamespace):
            def update(self, **kwargs: Any) -> None:
                for key, value in kwargs.items():
                    setattr(self, key, value)

        def __init__(self, *_, **__) -> None:
            self.conf = self._Config()
            self.control = _Control()

        def autodiscover_tasks(self, _packages: Iterable[str]) -> None:
            return None

        def task(self, *task_args: Any, **task_kwargs: Any):
            bind = bool(task_kwargs.get("bind", False))

            def decorator(func: Callable[..., Any]) -> _TaskWrapper:
                return _TaskWrapper(func, bind=bind)

            return decorator

from app.core.config import settings

celery_app = Celery(
    "repduel", broker=settings.CELERY_BROKER_URL, backend=settings.CELERY_RESULT_BACKEND
)

celery_app.conf.update(
    task_default_queue=settings.CELERY_TASK_DEFAULT_QUEUE,
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    broker_connection_retry_on_startup=True,
    task_always_eager=settings.CELERY_TASK_ALWAYS_EAGER,
    task_eager_propagates=True,
)

celery_app.autodiscover_tasks(["app.tasks"])

__all__ = ["celery_app"]
