"""Common pagination DTOs."""

from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PageParams(BaseModel):
    """Input pagination/filter parameters for list endpoints."""

    page: int = Field(default=1, ge=1, description="Page number (1-based)")
    page_size: int = Field(default=20, ge=1, le=200, description="Items per page")
    search: str | None = Field(default=None, max_length=200)


class Page(BaseModel, Generic[T]):
    """Output envelope for paginated collections (large-data handling)."""

    items: list[T]
    total: int
    page: int
    page_size: int
    pages: int
