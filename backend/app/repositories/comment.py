"""Comment repository — all DB queries for the ``comments`` table.

A comment is a recruiter note attached to a candidate; the author's display
name is joined in so the DTO carries everything the UI needs.
"""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import select

from app.db.vis import Vis
from app.dto.comment import CommentCreate, CommentRead
from app.models.comment import Comment
from app.models.user import User
from app.repositories.base import BaseRepository


class CommentRepository(BaseRepository[Comment, CommentRead, CommentCreate, CommentCreate]):
    model = Comment
    read_dto = CommentRead

    def create_for_candidate(self, data: CommentCreate, author_id: int) -> CommentRead:
        with Vis(self._factory) as session:
            obj = Comment(text=data.text, candidate_id=data.candidate_id, author_id=author_id)
            session.add(obj)
            session.flush()
            author = session.get(User, author_id)
            return CommentRead.model_validate(obj, from_attributes=True).model_copy(
                update={"author_name": author.full_name if author else None}
            )

    def list_by_candidate(self, candidate_id: int) -> list[CommentRead]:
        """Latest notes first; author name resolved via an explicit join."""
        with Vis(self._factory) as session:
            rows: Sequence[tuple[Comment, str | None]] = session.execute(
                select(Comment, User.full_name)
                .join(User, User.id == Comment.author_id)
                .where(Comment.candidate_id == candidate_id)
                .order_by(Comment.created_at.desc())
            ).all()
            result: list[CommentRead] = []
            for comment, author_name in rows:
                dto = CommentRead.model_validate(comment, from_attributes=True)
                result.append(dto.model_copy(update={"author_name": author_name}))
            return result
