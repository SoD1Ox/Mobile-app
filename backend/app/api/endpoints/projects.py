"""Project endpoints (main entity #1).

RBAC:
    read  — any authenticated user;
    write — manager / admin only.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_project_service
from app.dto.common import Page
from app.dto.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.services.errors import DomainError, NotFoundError, ValidationError
from app.services.project import ProjectService

router = APIRouter(prefix="/projects", tags=["projects"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    if isinstance(exc, ValidationError):
        return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[ProjectRead], summary="Paginated project list with search")
def list_projects(
    current_user: CurrentUser,
    service: ProjectService = Depends(get_project_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    search: str | None = Query(default=None, max_length=200),
) -> Page[ProjectRead]:
    from app.dto.common import PageParams

    return service.list_projects(PageParams(page=page, page_size=page_size, search=search))


@router.get("/{project_id}", response_model=ProjectRead, summary="Get a single project")
def get_project(
    project_id: int,
    current_user: CurrentUser,
    service: ProjectService = Depends(get_project_service),
) -> ProjectRead:
    try:
        return service.get_project(project_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post(
    "",
    response_model=ProjectRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a project (manager/admin)",
)
def create_project(
    data: ProjectCreate,
    current_user: ManagerOrAdmin,
    service: ProjectService = Depends(get_project_service),
) -> ProjectRead:
    try:
        return service.create_project(data)
    except (NotFoundError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.put(
    "/{project_id}",
    response_model=ProjectRead,
    summary="Update a project (manager/admin)",
)
def update_project(
    project_id: int,
    data: ProjectUpdate,
    current_user: ManagerOrAdmin,
    service: ProjectService = Depends(get_project_service),
) -> ProjectRead:
    try:
        return service.update_project(project_id, data)
    except (NotFoundError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.delete("/{project_id}", summary="Delete a project (manager/admin)")
def delete_project(
    project_id: int,
    current_user: ManagerOrAdmin,
    service: ProjectService = Depends(get_project_service),
) -> dict[str, str]:
    try:
        service.delete_project(project_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc
