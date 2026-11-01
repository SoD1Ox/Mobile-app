"""Comment DTOs (recruiter note about a candidate)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CommentCreate(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    candidate_id: int | None = Field(default=None, gt=0)


class CommentRead(BaseModel):
    id: int
    text: str
    candidate_id: int
    author_id: int
    author_name: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
