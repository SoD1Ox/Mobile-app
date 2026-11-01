"""Application DTOs (high-volume entity — candidate applying to a vacancy)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.application import ApplicationStatus


class ApplicationCreate(BaseModel):
    candidate_id: int | None = Field(
        default=None,
        gt=0,
        description="Existing candidate id; omit to create a self-application "
                    "from the vacancy card (name is then required)",
    )
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=30)
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
    # Audit trail of pipeline moves ("new -> review (by 2 @ 2026-11-01T14:03)")
    prev_status: str | None = None
    status_history: list[str] = Field(default_factory=list)
    # Funnel completion fraction 0..1 (self-learning stat)
    completion_score: float | None = None
    # Denormalized display fields resolved from ORM relationships
    # (candidate/vacancy/company/users). Optional so the DTO stays usable
    # even when a session cannot hydrate the relations.
    candidate_name: str | None = None
    vacancy_title: str | None = None
    company_name: str | None = None
    salary_from: float | None = None
    salary_to: float | None = None
    assigned_worker_name: str | None = None
    manager_name: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
