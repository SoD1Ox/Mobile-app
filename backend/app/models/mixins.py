"""Shared mixins for ORM models."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Float, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column


class TimestampMixin:
    """created_at / updated_at maintained by the database."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class StatusHistoryMixin:
    """Lightweight audit trail for status-pipeline entities.

    ``status_history`` accumulates entries like
    ``"new -> review (by 2 at 2026-11-01T14:03+00:00)"`` every time the
    status changes; ``prev_status`` keeps the last value for quick diffs.
    Stored as plain columns so no extra table/joins are needed — the UI
    renders it as a timeline without additional endpoints.
    """

    prev_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    status_history: Mapped[str] = mapped_column(
        Text, nullable=False, default="", server_default=""
    )
    completion_score: Mapped[float | None] = mapped_column(Float, nullable=True)
