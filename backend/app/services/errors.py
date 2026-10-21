"""Domain errors raised by the service layer.

The API layer translates them into HTTP responses, so services stay free of
FastAPI/HTTP specifics (separation of concerns).
"""

from __future__ import annotations


class DomainError(Exception):
    """Base class for business-rule violations."""

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class NotFoundError(DomainError):
    """Requested entity does not exist (HTTP 404)."""


class ConflictError(DomainError):
    """Uniqueness / state conflict, e.g. duplicate username (HTTP 409)."""


class AuthenticationError(DomainError):
    """Bad credentials or invalid token (HTTP 401)."""


class PermissionDeniedError(DomainError):
    """Authenticated but role lacks rights (HTTP 403)."""


class ValidationError(DomainError):
    """Business validation failed (HTTP 422)."""
