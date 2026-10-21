"""Project DTOs."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class ProjectBase(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    budget: Decimal = Field(default=Decimal("0"), ge=0)
    client_id: int = Field(gt=0)


class ProjectCreate(ProjectBase):
    pass


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = None
    budget: Decimal | None = Field(default=None, ge=0)
    client_id: int | None = Field(default=None, gt=0)


class ProjectRead(BaseModel):
    id: int
    name: str
    description: str | None
    budget: Decimal
    client_id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
