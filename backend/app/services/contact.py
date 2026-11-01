"""Contact service — business logic between API and ContactRepository."""

from __future__ import annotations

from app.dto.contact import ContactCreate, ContactRead, ContactUpdate
from app.repositories.contact import ContactRepository
from app.services.errors import NotFoundError


class ContactService:
    def __init__(self, repo: ContactRepository | None = None) -> None:
        self._repo = repo or ContactRepository()

    def list_by_company(self, company_id: int) -> list[ContactRead]:
        return self._repo.list_by_company(company_id)

    def get_contact(self, contact_id: int) -> ContactRead:
        contact = self._repo.get_by_id(contact_id)
        if contact is None:
            raise NotFoundError(f"Contact {contact_id} not found")
        return contact

    def create_contact(self, data: ContactCreate) -> ContactRead:
        return self._repo.create(data)

    def update_contact(self, contact_id: int, data: ContactUpdate) -> ContactRead:
        updated = self._repo.update(contact_id, data)
        if updated is None:
            raise NotFoundError(f"Contact {contact_id} not found")
        return updated

    def delete_contact(self, contact_id: int) -> None:
        if not self._repo.delete(contact_id):
            raise NotFoundError(f"Contact {contact_id} not found")
