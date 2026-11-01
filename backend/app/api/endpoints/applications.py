"""Application endpoints (high-volume entity — candidate pipeline).

Role hierarchy (staffing-agency domain):
    admin   — full control: everything + delete + user management;
    manager — recruiter: sees the WHOLE pipeline, moves statuses,
              assigns a responsible worker to an application;
    worker  — executor: sees ONLY applications assigned to them and may
              move their status forward (own queue of cases);
    unauthenticated — HTTP 401 on every endpoint.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import AdminUser, CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_application_service
from app.dto.application import ApplicationCreate, ApplicationRead, ApplicationUpdate
from app.dto.common import Page, PageParams
from app.models.application import ApplicationStatus
from app.models.user import UserRole
from app.services.application import ApplicationService
from app.services.errors import ConflictError, DomainError, NotFoundError, ValidationError


def _forbidden(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)

router = APIRouter(prefix="/applications", tags=["applications"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    if isinstance(exc, ConflictError):
        return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message)
    if isinstance(exc, ValidationError):
        return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[ApplicationRead], summary="Paginated application list")
def list_applications(
    current_user: CurrentUser,
    service: ApplicationService = Depends(get_application_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    vacancy_id: int | None = Query(default=None, ge=1),
    candidate_id: int | None = Query(default=None, ge=1),
    status_filter: ApplicationStatus | None = Query(default=None, alias="status"),
    manager_id: int | None = Query(default=None, ge=1),
    mine: bool = Query(
        default=False,
        description="Worker only: return applications assigned to the current user",
    ),
) -> Page[ApplicationRead]:
    # Hierarchy: a worker's view is always scoped to their own assignments.
    if current_user.role == UserRole.WORKER:
        return service.list_applications(
            PageParams(page=page, page_size=page_size),
            vacancy_id=vacancy_id,
            candidate_id=candidate_id,
            status=status_filter,
            assigned_worker_id=current_user.id,
        )
    if mine:
        return service.list_applications(
            PageParams(page=page, page_size=page_size),
            vacancy_id=vacancy_id,
            candidate_id=candidate_id,
            status=status_filter,
            manager_id=manager_id,
            assigned_worker_id=current_user.id,
        )
    return service.list_applications(
        PageParams(page=page, page_size=page_size),
        vacancy_id=vacancy_id,
        candidate_id=candidate_id,
        status=status_filter,
        manager_id=manager_id,
    )


@router.get("/{application_id}", response_model=ApplicationRead, summary="Get one application")
def get_application(
    application_id: int,
    current_user: CurrentUser,
    service: ApplicationService = Depends(get_application_service),
) -> ApplicationRead:
    try:
        app = service.get_application(application_id)
        if (
            current_user.role == UserRole.WORKER
            and app.assigned_worker_id != current_user.id
        ):
            raise _forbidden("This application is not assigned to you")
        return app
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post(
    "",
    response_model=ApplicationRead,
    status_code=status.HTTP_201_CREATED,
    summary="Register an application (candidate -> vacancy)",
)
def create_application(
    data: ApplicationCreate,
    current_user: CurrentUser,
    service: ApplicationService = Depends(get_application_service),
) -> ApplicationRead:
    try:
        return service.create_application(data)
    except (NotFoundError, ConflictError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.patch(
    "/{application_id}", response_model=ApplicationRead, summary="Move pipeline status (manager/admin)"
)
def update_application(
    application_id: int,
    data: ApplicationUpdate,
    current_user: ManagerOrAdmin,
    service: ApplicationService = Depends(get_application_service),
) -> ApplicationRead:
    try:
        return service.update_application(application_id, data)
    except (NotFoundError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.delete("/{application_id}", summary="Delete an application (admin)")
def delete_application(
    application_id: int,
    current_user: AdminUser,
    service: ApplicationService = Depends(get_application_service),
) -> dict[str, str]:
    try:
        service.delete_application(application_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc
