"""Company endpoints (partner employers of the staffing agency).

RBAC:
    read  — any authenticated user;
    write — manager / admin only.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_company_service, get_contact_service
from app.dto.common import Page, PageParams
from app.dto.company import CompanyCreate, CompanyRead, CompanyUpdate
from app.dto.contact import ContactCreate, ContactRead, ContactUpdate
from app.services.contact import ContactService
from app.services.company import CompanyService
from app.services.errors import DomainError, NotFoundError

router = APIRouter(prefix="/companies", tags=["companies"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[CompanyRead], summary="Paginated company list with search")
def list_companies(
    current_user: CurrentUser,
    service: CompanyService = Depends(get_company_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    search: str | None = Query(default=None, max_length=200),
) -> Page[CompanyRead]:
    return service.list_companies(PageParams(page=page, page_size=page_size, search=search))


@router.get("/{company_id}", response_model=CompanyRead, summary="Get a single company")
def get_company(
    company_id: int,
    current_user: CurrentUser,
    service: CompanyService = Depends(get_company_service),
) -> CompanyRead:
    try:
        return service.get_company(company_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post(
    "",
    response_model=CompanyRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a company (manager/admin)",
)
def create_company(
    data: CompanyCreate,
    current_user: ManagerOrAdmin,
    service: CompanyService = Depends(get_company_service),
) -> CompanyRead:
    return service.create_company(data)


@router.put("/{company_id}", response_model=CompanyRead, summary="Update a company (manager/admin)")
def update_company(
    company_id: int,
    data: CompanyUpdate,
    current_user: ManagerOrAdmin,
    service: CompanyService = Depends(get_company_service),
) -> CompanyRead:
    try:
        return service.update_company(company_id, data)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.delete("/{company_id}", summary="Delete a company (manager/admin)")
def delete_company(
    company_id: int,
    current_user: ManagerOrAdmin,
    service: CompanyService = Depends(get_company_service),
) -> dict[str, str]:
    try:
        service.delete_company(company_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc

# ---------------------------------------------------------------- contacts ---
# Contacts are nested under companies: /companies/{company_id}/contacts

contact_router = APIRouter(prefix="/contacts", tags=["contacts"])


@router.get("/{company_id}/contacts", response_model=list[ContactRead],
            summary="Contacts of a company (authenticated)")
def list_company_contacts(
    company_id: int,
    current_user: CurrentUser,
    service: ContactService = Depends(get_contact_service),
) -> list[ContactRead]:
    return service.list_by_company(company_id)


@contact_router.get("/{contact_id}", response_model=ContactRead, summary="Get one contact")
def get_contact(
    contact_id: int,
    current_user: CurrentUser,
    service: ContactService = Depends(get_contact_service),
) -> ContactRead:
    try:
        return service.get_contact(contact_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@contact_router.post("", response_model=ContactRead, status_code=status.HTTP_201_CREATED,
                     summary="Create a contact (manager/admin)")
def create_contact(
    data: ContactCreate,
    current_user: ManagerOrAdmin,
    service: ContactService = Depends(get_contact_service),
) -> ContactRead:
    return service.create_contact(data)


@contact_router.put("/{contact_id}", response_model=ContactRead,
                    summary="Update a contact (manager/admin)")
def update_contact(
    contact_id: int,
    data: ContactUpdate,
    current_user: ManagerOrAdmin,
    service: ContactService = Depends(get_contact_service),
) -> ContactRead:
    try:
        return service.update_contact(contact_id, data)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@contact_router.delete("/{contact_id}", summary="Delete a contact (manager/admin)")
def delete_contact(
    contact_id: int,
    current_user: ManagerOrAdmin,
    service: ContactService = Depends(get_contact_service),
) -> dict[str, str]:
    try:
        service.delete_contact(contact_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc
