"""Contact repository — all DB queries for the ``contacts`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import select

from app.db.vis import Vis
from app.dto.contact import ContactCreate, ContactRead, ContactUpdate
from app.models.contact import Contact
from app.repositories.base import BaseRepository


class ContactRepository(BaseRepository[Contact, ContactRead, ContactCreate, ContactUpdate]):
    model = Contact
    read_dto = ContactRead

    def list_by_client(self, client_id: int) -> list[ContactRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Contact] = session.scalars(
                select(Contact).where(Contact.client_id == client_id).order_by(Contact.full_name)
            ).all()
            return [ContactRead.model_validate(r, from_attributes=True) for r in rows]
