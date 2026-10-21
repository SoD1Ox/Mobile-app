"""Task DTOs (including the high-volume paginated list output)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.dto.tag import TagRead
from app.models.task import TaskPriority, TaskStatus


class TaskBase(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    status: TaskStatus = TaskStatus.NEW
    priority: TaskPriority = TaskPriority.MEDIUM
    estimate_hours: int = Field(default=0, ge=0, le=10000)
    project_id: int = Field(gt=0)
    author_id: int | None = Field(default=None, gt=0)
    tag_ids: list[int] = Field(default_factory=list)


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = None
    status: TaskStatus | None = None
    priority: TaskPriority | None = None
    estimate_hours: int | None = Field(default=None, ge=0, le=10000)
    project_id: int | None = Field(default=None, gt=0)
    tag_ids: list[int] | None = None


class TaskRead(BaseModel):
    id: int
    title: str
    description: str | None
    status: TaskStatus
    priority: TaskPriority
    estimate_hours: int
    project_id: int
    author_id: int
    tags: list[TagRead] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
