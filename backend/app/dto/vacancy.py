"""Vacancy DTOs (main entity — open position of a partner company)."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import field_validator, BaseModel, ConfigDict, Field

from app.dto.skill import SkillRead


class VacancyBase(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    salary_from: Decimal | None = Field(default=None, ge=0)
    salary_to: Decimal | None = Field(default=None, ge=0)
    city: str | None = Field(default=None, max_length=80)
    remote: bool = False
    company_id: int = Field(gt=0)
    skill_ids: list[int] = Field(default_factory=list)


class VacancyCreate(VacancyBase):
    pass


class VacancyUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = None
    salary_from: Decimal | None = Field(default=None, ge=0)
    salary_to: Decimal | None = Field(default=None, ge=0)
    city: str | None = Field(default=None, max_length=80)
    remote: bool | None = None
    company_id: int | None = Field(default=None, gt=0)
    skill_ids: list[int] | None = None


class VacancyRead(BaseModel):
    id: int
    title: str
    description: str | None
    salary_from: Decimal | None
    salary_to: Decimal | None
    city: str | None
    remote: bool
    company_id: int
    skills: list[SkillRead] = Field(default_factory=list)
    # Self-learning stats (filled by the service layer from application funnel)
    completion_score: float | None = None
    status_history: list[str] = Field(default_factory=list)

    @field_validator("status_history", mode="before")
    @classmethod
    def _split_history(cls, v):
        if isinstance(v, str):
            return [x for x in v.split("\n") if x.strip()]
        return v or []
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
