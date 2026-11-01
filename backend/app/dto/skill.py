"""Skill DTO (auxiliary entity, many-to-many with vacancies)."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class SkillBase(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class SkillCreate(SkillBase):
    pass


class SkillRead(BaseModel):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)
