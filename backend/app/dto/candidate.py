"""Candidate DTOs (main entity — job seeker of the staffing agency)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class CandidateBase(BaseModel):
    full_name: str = Field(min_length=2, max_length=150)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=30)
    city: str | None = Field(default=None, max_length=80)
    specialization: str | None = Field(default=None, max_length=100)
    experience_years: int = Field(default=0, ge=0, le=70)
    resume_url: str | None = Field(default=None, max_length=255)


class CandidateCreate(CandidateBase):
    pass


class CandidateUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=30)
    city: str | None = Field(default=None, max_length=80)
    specialization: str | None = Field(default=None, max_length=100)
    experience_years: int | None = Field(default=None, ge=0, le=70)
    resume_url: str | None = Field(default=None, max_length=255)


class CandidateRead(BaseModel):
    id: int
    full_name: str
    email: str | None
    phone: str | None
    city: str | None
    specialization: str | None
    experience_years: int
    resume_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
