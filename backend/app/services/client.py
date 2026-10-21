"""Client service — business logic for the ``clients`` entity (+ its contacts)."""

from __future__ import annotations

from app.dto.client import ClientCreate, ClientRead, ClientUpdate
from app.dto.common import Page, PageParams
from app.dto.contact import ContactCreate, ContactRead, ContactUpdate
from app.repositories.client import ClientRepository
from app.repositories.contact import ContactRepository
from app.services.errors import ConflictError, NotFoundError


class ClientService:
    def __init__(
        self,
        repo: ClientRepository | None = None,
        contact_repo: ContactRepository | None = None,
    ) -> None:
        self._repo = repo or ClientRepository()
        self._contact_repo = contact_repo or ContactRepository()

    # --------------------------------------------------------------- clients
    def list_clients(self, params: PageParams) -> Page[ClientRead]:
        return self._repo.search_paginated(params)

    def get_client(self, client_id: int) -> ClientRead:
        client = self._repo.get_by_id(client_id)
        if client is None:
            raise NotFoundError(f"Client {client_id} not found")
        return client

    def create_client(self, data: ClientCreate) -> ClientRead:
        if data.email and self._repo.get_by_email(data.email):
            raise ConflictError(f"Client with email {data.email} already exists")
        return self._repo.create(data)

    def update_client(self, client_id: int, data: ClientUpdate) -> ClientRead:
        self.get_client(client_id)  # 404 if missing
        if data.email:
            existing = self._repo.get_by_email(data.email)
            if existing is not None and existing.id != client_id:
                raise ConflictError(f"Client with email {data.email} already exists")
        updated = self._repo.update(client_id, data)
        if updated is None:
            raise NotFoundError(f"Client {client_id} not found")
        return updated

    def delete_client(self, client_id: int) -> None:
        if not self._repo.delete(client_id):
            raise NotFoundError(f"Client {client_id} not found")

    # -------------------------------------------------------------- contacts
    def list_contacts(self, client_id: int) -> list[ContactRead]:
        self.get_client(client_id)
        return self._contact_repo.list_by_client(client_id)

    def add_contact(self, client_id: int, data: ContactCreate) -> ContactRead:
        self.get_client(client_id)
        if data.client_id != client_id:
            raise ConflictError("client_id in body does not match path")
        return self._contact_repo.create(data)

    def update_contact(self, contact_id: int, data: ContactUpdate) -> ContactRead:
        contact = self._contact_repo.get_by_id(contact_id)
        if contact is None:
            raise NotFoundError(f"Contact {contact_id} not found")
        updated = self._contact_repo.update(contact_id, data)
        if updated is None:
            raise NotFoundError(f"Contact {contact_id} not found")
        return updated

    def delete_contact(self, contact_id: int) -> None:
        if not self._contact_repo.delete(contact_id):
            raise NotFoundError(f"Contact {contact_id} not found")
