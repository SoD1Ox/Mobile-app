"""Vacancy endpoints (main entity — open positions of partner companies).

Large-data mechanism: paginated list + filters (company / city / remote /
salary) + ILIKE search over title and description.

RBAC:
    read  — any authenticated user;
    write — manager / admin only.
"""

from __future__ import annotations

from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_vacancy_service
from app.dto.common import Page, PageParams
from app.dto.vacancy import VacancyCreate, VacancyRead, VacancyUpdate
from app.services.errors import DomainError, NotFoundError, ValidationError
from app.services.vacancy import VacancyService

router = APIRouter(prefix="/vacancies", tags=["vacancies"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    if isinstance(exc, ValidationError):
        return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[VacancyRead], summary="Paginated vacancy list (large data)")
def list_vacancies(
    current_user: CurrentUser,
    service: VacancyService = Depends(get_vacancy_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    search: str | None = Query(default=None, max_length=200),
    company_id: int | None = Query(default=None, ge=1),
    city: str | None = Query(default=None, max_length=80),
    remote: bool | None = Query(default=None),
    salary_min: Decimal | None = Query(default=None, ge=0),
    ids: str | None = Query(default=None, max_length=2000,
                            description="Comma-separated vacancy ids (batch fetch)"),
) -> Page[VacancyRead]:
    id_list: list[int] | None = None
    if ids:
        try:
            id_list = [int(x) for x in ids.split(",") if x.strip()]
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="ids must be comma-separated integers") from exc
    return service.list_vacancies(
        PageParams(page=page, page_size=page_size, search=search),
        company_id=company_id,
        city=city,
        remote=remote,
        salary_min=salary_min,
        ids=id_list,
    )


@router.get("/{vacancy_id}", response_model=VacancyRead, summary="Get a single vacancy")
def get_vacancy(
    vacancy_id: int,
    current_user: CurrentUser,
    service: VacancyService = Depends(get_vacancy_service),
) -> VacancyRead:
    try:
        return service.get_vacancy(vacancy_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post(
    "",
    response_model=VacancyRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a vacancy (manager/admin)",
)
def create_vacancy(
    data: VacancyCreate,
    current_user: ManagerOrAdmin,
    service: VacancyService = Depends(get_vacancy_service),
) -> VacancyRead:
    try:
        return service.create_vacancy(data)
    except (NotFoundError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.put("/{vacancy_id}", response_model=VacancyRead, summary="Update a vacancy (manager/admin)")
def update_vacancy(
    vacancy_id: int,
    data: VacancyUpdate,
    current_user: ManagerOrAdmin,
    service: VacancyService = Depends(get_vacancy_service),
) -> VacancyRead:
    try:
        return service.update_vacancy(vacancy_id, data)
    except (NotFoundError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.delete("/{vacancy_id}", summary="Delete a vacancy (manager/admin)")
def delete_vacancy(
    vacancy_id: int,
    current_user: ManagerOrAdmin,
    service: VacancyService = Depends(get_vacancy_service),
) -> dict[str, str]:
    try:
        service.delete_vacancy(vacancy_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc
