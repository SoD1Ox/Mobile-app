"""Comment DTOs."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CommentBase(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class CommentCreate(CommentBase):
    task_id: int = Field(gt=0)


class CommentRead(BaseModel):
    id: int
    text: str
    task_id: int
    author_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
