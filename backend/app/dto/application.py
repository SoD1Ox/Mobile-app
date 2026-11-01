"""Application DTOs (high-volume entity — candidate applying to a vacancy)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.application import ApplicationStatus


class ApplicationCreate(BaseModel):
    candidate_id: int = Field(gt=0)
    vacancy_id: int = Field(gt=0)
    manager_id: int | None = Field(default=None, gt=0)
    assigned_worker_id: int | None = Field(default=None, gt=0)


class ApplicationUpdate(BaseModel):
    """Pipeline status and the responsible recruiter / assigned worker."""

    status: ApplicationStatus | None = None
    manager_id: int | None = Field(default=None, gt=0)
    assigned_worker_id: int | None = Field(default=None, gt=0)


class ApplicationRead(BaseModel):
    id: int
    status: ApplicationStatus
    candidate_id: int
    vacancy_id: int
    manager_id: int | None
    assigned_worker_id: int | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
