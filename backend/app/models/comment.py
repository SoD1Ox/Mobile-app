"""Comment ORM model (auxiliary entity: discussion on a task)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.task import Task
    from app.models.user import User


class Comment(TimestampMixin, Base):
    __tablename__ = "comments"

    id: Mapped[int] = mapped_column(primary_key=True)
    text: Mapped[str] = mapped_column(String(2000), nullable=False)

    # many comments -> one task
    task_id: Mapped[int] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), index=True, nullable=False
    )
    task: Mapped["Task"] = relationship(back_populates="comments")

    # many comments -> one author (user)
    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    author: Mapped["User"] = relationship()

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Comment id={self.id} task_id={self.task_id}>"
