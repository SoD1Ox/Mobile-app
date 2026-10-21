"""Comment repository — all DB queries for the ``comments`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import select

from app.db.vis import Vis
from app.dto.comment import CommentCreate, CommentRead
from app.models.comment import Comment
from app.repositories.base import BaseRepository


class CommentRepository(BaseRepository[Comment, CommentRead, CommentCreate, CommentCreate]):
    model = Comment
    read_dto = CommentRead

    def create_for_task(self, data: CommentCreate, author_id: int) -> CommentRead:
        with Vis(self._factory) as session:
            obj = Comment(text=data.text, task_id=data.task_id, author_id=author_id)
            session.add(obj)
            session.flush()
            return CommentRead.model_validate(obj, from_attributes=True)

    def list_by_task(self, task_id: int) -> list[CommentRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Comment] = session.scalars(
                select(Comment)
                .where(Comment.task_id == task_id)
                .order_by(Comment.created_at.desc())
            ).all()
            return [CommentRead.model_validate(r, from_attributes=True) for r in rows]
