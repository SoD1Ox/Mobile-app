"""JWT authentication & role-based authorization dependencies.

* ``get_current_user``  — any authenticated (active) user;
* ``require_roles(...)`` — factory for role-restricted endpoints (RBAC);
* unauthenticated / invalid-token requests get HTTP 401 with a clear message.
"""

from __future__ import annotations

from typing import Annotated, Callable

import jwt as pyjwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.dto.user import UserRead
from app.models.user import UserRole
from app.repositories.user import UserRepository
from app.security.security import decode_token

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(_bearer)
    ],
) -> UserRead:
    """Resolve the authenticated user from the ``Authorization: Bearer`` header."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_token(credentials.credentials, expected_type="access")
    except pyjwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    user = UserRepository().get_by_id(payload.sub)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")
    return user


def require_roles(*roles: UserRole) -> Callable[..., UserRead]:
    """Dependency factory: allow only the listed roles (otherwise HTTP 403)."""

    def checker(current_user: Annotated[UserRead, Depends(get_current_user)]) -> UserRead:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of roles: {', '.join(r.value for r in roles)}",
            )
        return current_user

    return checker


# Handy annotated aliases for endpoints
CurrentUser = Annotated[UserRead, Depends(get_current_user)]
AdminUser = Annotated[UserRead, Depends(require_roles(UserRole.ADMIN))]
ManagerOrAdmin = Annotated[UserRead, Depends(require_roles(UserRole.ADMIN, UserRole.MANAGER))]
