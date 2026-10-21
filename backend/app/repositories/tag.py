"""Tag repository — all DB queries for the ``tags`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import select

from app.db.vis import Vis
from app.dto.tag import TagCreate, TagRead
from app.models.tag import Tag
from app.repositories.base import BaseRepository


class TagRepository(BaseRepository[Tag, TagRead, TagCreate, TagCreate]):
    model = Tag
    read_dto = TagRead

    def get_or_create_many(self, names: list[str]) -> list[TagRead]:
        """Resolve tag names to tags, creating missing ones (single session)."""
        cleaned = sorted({n.strip().lower() for n in names if n.strip()})
        with Vis(self._factory) as session:
            existing = list(session.scalars(select(Tag).where(Tag.name.in_(cleaned))))
            existing_names = {t.name for t in existing}
            new_tags = [Tag(name=n) for n in cleaned if n not in existing_names]
            session.add_all(new_tags)
            session.flush()
            result = existing + new_tags
            return [TagRead.model_validate(t, from_attributes=True) for t in result]

    def list_ordered(self) -> list[TagRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Tag] = session.scalars(select(Tag).order_by(Tag.name)).all()
            return [TagRead.model_validate(r, from_attributes=True) for r in rows]
