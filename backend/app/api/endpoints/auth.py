"""Auth endpoints: login / register / refresh / me.

Endpoints are thin: they validate input via pydantic DTOs, delegate to the
service layer and translate domain errors into HTTP responses.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies.auth import CurrentUser
from app.api.dependencies.providers import get_user_service
from app.dto.auth import TokenPair
from app.dto.user import UserLogin, UserRead, UserRegister
from app.services.errors import (
    AuthenticationError,
    ConflictError,
    PermissionDeniedError,
)
from app.services.user import UserService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=TokenPair,
    status_code=status.HTTP_201_CREATED,
    summary="Public self-registration (role is forced to 'worker')",
)
def register(data: UserRegister, service: UserService = Depends(get_user_service)) -> TokenPair:
    try:
        return service.register(data)
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message) from exc


@router.post("/login", response_model=TokenPair, summary="Obtain JWT access+refresh pair")
def login(data: UserLogin, service: UserService = Depends(get_user_service)) -> TokenPair:
    try:
        return service.login(data.username, data.password)
    except AuthenticationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=exc.message,
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except PermissionDeniedError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=exc.message) from exc


@router.post("/refresh", response_model=TokenPair, summary="Exchange refresh token for a new pair")
def refresh(tokens: TokenPair, service: UserService = Depends(get_user_service)) -> TokenPair:
    """Body only needs ``refresh_token``; ``access_token`` may be an empty string."""
    try:
        return service.refresh(tokens.refresh_token)
    except AuthenticationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=exc.message,
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


@router.get("/me", response_model=UserRead, summary="Currently authenticated user profile")
def me(current_user: CurrentUser) -> UserRead:
    return current_user
