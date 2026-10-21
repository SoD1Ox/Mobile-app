"""Client repository — all DB queries for the ``clients`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, or_, select

from app.db.vis import Vis
from app.dto.client import ClientCreate, ClientRead, ClientUpdate
from app.dto.common import Page, PageParams
from app.models.client import Client
from app.repositories.base import BaseRepository


class ClientRepository(BaseRepository[Client, ClientRead, ClientCreate, ClientUpdate]):
    model = Client
    read_dto = ClientRead

    def get_by_email(self, email: str) -> ClientRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(select(Client).where(Client.email == email))
            return self._to_read(obj)

    def search_paginated(self, params: PageParams) -> Page[ClientRead]:
        with Vis(self._factory) as session:
            stmt = select(Client)
            count_stmt = select(func.count()).select_from(Client)
            if params.search:
                pattern = f"%{params.search.lower()}%"
                cond = or_(
                    Client.name.ilike(pattern),  # type: ignore[attr-defined]
                    Client.email.ilike(pattern),  # type: ignore[attr-defined]
                )
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Client] = session.scalars(
                stmt.order_by(Client.id)
                .offset((params.page - 1) * params.page_size)
                .limit(params.page_size)
            ).all()
            items = [self._to_read(r) for r in rows]  # type: ignore[misc]
            pages = (total + params.page_size - 1) // params.page_size
            return Page(
                items=items,  # type: ignore[arg-type]
                total=total,
                page=params.page,
                page_size=params.page_size,
                pages=pages,
            )
