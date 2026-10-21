"""Base (generic) repository.

A repository encapsulates **all** SQLAlchemy queries for a single entity.
Every public method opens its own session through the ``Vis`` context manager
(session-per-operation), works inside it, and returns plain DTOs — never ORM
objects — so nothing can trigger lazy loading after the session is closed.
"""

from __future__ import annotations

from typing import Callable, Generic, Sequence, TypeVar

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.vis import Vis, get_session_factory
from app.dto.common import Page, PageParams

ModelT = TypeVar("ModelT", bound=Base)
ReadDTOT = TypeVar("ReadDTOT")
CreateDTOT = TypeVar("CreateDTOT")
UpdateDTOT = TypeVar("UpdateDTOT")


class BaseRepository(Generic[ModelT, ReadDTOT, CreateDTOT, UpdateDTOT]):
    """Common CRUD + pagination logic shared by all entity repositories."""

    model: type[ModelT]
    read_dto: type[ReadDTOT]

    def __init__(self, factory: Callable[[], Session] | None = None) -> None:
        # Session factory: every call produces a brand-new Session.
        self._factory = factory or get_session_factory()

    # ------------------------------------------------------------------ helpers
    def _to_read(self, obj: ModelT | None) -> ReadDTOT | None:
        if obj is None:
            return None
        return self.read_dto.model_validate(obj, from_attributes=True)

    # ------------------------------------------------------------------- CRUD
    def get_by_id(self, entity_id: int) -> ReadDTOT | None:
        with Vis(self._factory) as session:
            obj = session.get(self.model, entity_id)
            return self._to_read(obj)

    def list_all(self) -> list[ReadDTOT]:
        with Vis(self._factory) as session:
            rows: Sequence[ModelT] = session.scalars(
                select(self.model).order_by(self.model.id)  # type: ignore[attr-defined]
            ).all()
            return [self._to_read(r) for r in rows]  # type: ignore[misc]

    def paginate(self, params: PageParams) -> Page[ReadDTOT]:
        """Large-data handling: LIMIT/OFFSET pagination + total count."""
        with Vis(self._factory) as session:
            total = session.scalar(select(func.count()).select_from(self.model)) or 0
            offset = (params.page - 1) * params.page_size
            rows = session.scalars(
                select(self.model)
                .order_by(self.model.id)  # type: ignore[attr-defined]
                .offset(offset)
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

    def create(self, data: CreateDTOT) -> ReadDTOT:
        with Vis(self._factory) as session:
            obj = self.model(**data.model_dump())
            session.add(obj)
            session.flush()  # obtain PK / server defaults before DTO conversion
            return self._to_read(obj)  # type: ignore[return-value]

    def update(self, entity_id: int, data: UpdateDTOT) -> ReadDTOT | None:
        payload = data.model_dump(exclude_unset=True)
        with Vis(self._factory) as session:
            obj = session.get(self.model, entity_id)
            if obj is None:
                return None
            for field, value in payload.items():
                setattr(obj, field, value)
            session.flush()
            return self._to_read(obj)  # type: ignore[return-value]

    def delete(self, entity_id: int) -> bool:
        with Vis(self._factory) as session:
            obj = session.get(self.model, entity_id)
            if obj is None:
                return False
            session.delete(obj)
            return True

    def exists(self, entity_id: int) -> bool:
        with Vis(self._factory) as session:
            return session.get(self.model, entity_id) is not None

