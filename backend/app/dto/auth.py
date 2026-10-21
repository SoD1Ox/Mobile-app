"""Auth DTOs: JWT token pair and decoded payload."""

from __future__ import annotations

from pydantic import BaseModel

from app.models.user import UserRole


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    sub: int
    role: UserRole
    type: str  # "access" | "refresh"
