"""Client endpoints (main entity #3) + nested contact-person CRUD.

RBAC:
    read  — any authenticated user;
    write — manager / admin only.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_client_service
from app.dto.client import ClientCreate, ClientRead, ClientUpdate
from app.dto.common import Page, PageParams
from app.dto.contact import ContactCreate, ContactRead, ContactUpdate
from app.services.client import ClientService
from app.services.errors import ConflictError, DomainError, NotFoundError, ValidationError

router = APIRouter(prefix="/clients", tags=["clients"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    if isinstance(exc, ConflictError):
        return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message)
    if isinstance(exc, ValidationError):
        return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[ClientRead], summary="Paginated client list with search")
def list_clients(
    current_user: CurrentUser,
    service: ClientService = Depends(get_client_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    search: str | None = Query(default=None, max_length=200),
) -> Page[ClientRead]:
    return service.list_clients(PageParams(page=page, page_size=page_size, search=search))


@router.get("/{client_id}", response_model=ClientRead, summary="Get a single client")
def get_client(
    client_id: int,
    current_user: CurrentUser,
    service: ClientService = Depends(get_client_service),
) -> ClientRead:
    try:
        return service.get_client(client_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post("", response_model=ClientRead, status_code=status.HTTP_201_CREATED,
             summary="Create a client (manager/admin)")
def create_client(
    data: ClientCreate,
    current_user: ManagerOrAdmin,
    service: ClientService = Depends(get_client_service),
) -> ClientRead:
    try:
        return service.create_client(data)
    except ConflictError as exc:
        raise _http_error(exc) from exc


@router.put("/{client_id}", response_model=ClientRead, summary="Update a client (manager/admin)")
def update_client(
    client_id: int,
    data: ClientUpdate,
    current_user: ManagerOrAdmin,
    service: ClientService = Depends(get_client_service),
) -> ClientRead:
    try:
        return service.update_client(client_id, data)
    except DomainError as exc:
        raise _http_error(exc) from exc


@router.delete("/{client_id}", summary="Delete a client (manager/admin)")
def delete_client(
    client_id: int,
    current_user: ManagerOrAdmin,
    service: ClientService = Depends(get_client_service),
) -> dict[str, str]:
    try:
        service.delete_client(client_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc


# ------------------------------------------------------------------ contacts
@router.get("/{client_id}/contacts", response_model=list[ContactRead],
            summary="List contact persons of a client")
def list_contacts(
    client_id: int,
    current_user: CurrentUser,
    service: ClientService = Depends(get_client_service),
) -> list[ContactRead]:
    try:
        return service.list_contacts(client_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post("/{client_id}/contacts", response_model=ContactRead,
             status_code=status.HTTP_201_CREATED,
             summary="Add a contact person (manager/admin)")
def add_contact(
    client_id: int,
    data: ContactCreate,
    current_user: ManagerOrAdmin,
    service: ClientService = Depends(get_client_service),
) -> ContactRead:
    try:
        return service.add_contact(client_id, data)
    except DomainError as exc:
        raise _http_error(exc) from exc


@router.put("/contacts/{contact_id}", response_model=ContactRead,
            summary="Update a contact person (manager/admin)")
def update_contact(
    contact_id: int,
    data: ContactUpdate,
    current_user: ManagerOrAdmin,
    service: ClientService = Depends(get_client_service),
) -> ContactRead:
    try:
        return service.update_contact(contact_id, data)
    except DomainError as exc:
        raise _http_error(exc) from exc


@router.delete("/contacts/{contact_id}", summary="Delete a contact person (manager/admin)")
def delete_contact(
    contact_id: int,
    current_user: ManagerOrAdmin,
    service: ClientService = Depends(get_client_service),
) -> dict[str, str]:
    try:
        service.delete_contact(contact_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc
