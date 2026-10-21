"""User endpoints (4th, security entity).

RBAC: listing/creating/updating/deleting users requires the ADMIN role;
everyone else gets 403. Self-info is available to any authenticated user
via ``/auth/me``.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import AdminUser, CurrentUser
from app.api.dependencies.providers import get_user_service
from app.dto.user import UserCreate, UserRead, UserUpdate
from app.services.errors import ConflictError, NotFoundError
from app.services.user import UserService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserRead], summary="List all users (admin only)")
def list_users(
    service: UserService = Depends(get_user_service),
    _: AdminUser = None,  # type: ignore[assignment]
    search: str | None = Query(default=None, min_length=1, max_length=200),
) -> list[UserRead]:
    if search:
        return service.search(search)
    return service.list_users()


@router.get("/{user_id}", response_model=UserRead, summary="Get one user (authenticated)")
def get_user(
    user_id: int,
    service: UserService = Depends(get_user_service),
    current_user: CurrentUser = None,  # type: ignore[assignment]
) -> UserRead:
    try:
        return service.get_user(user_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc


@router.post(
    "",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a user with explicit role (admin only)",
)
def create_user(
    data: UserCreate,
    service: UserService = Depends(get_user_service),
    _: AdminUser = None,  # type: ignore[assignment]
) -> UserRead:
    try:
        return service.create_user(data)
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message) from exc


@router.put("/{user_id}", response_model=UserRead, summary="Update a user (admin only)")
def update_user(
    user_id: int,
    data: UserUpdate,
    service: UserService = Depends(get_user_service),
    _: AdminUser = None,  # type: ignore[assignment]
) -> UserRead:
    try:
        return service.update_user(user_id, data)
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message) from exc


@router.delete("/{user_id}", summary="Hard-delete a user (admin only)")
def delete_user(
    user_id: int,
    service: UserService = Depends(get_user_service),
    _: AdminUser = None,  # type: ignore[assignment]
) -> dict[str, str]:
    try:
        service.delete_user(user_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc
