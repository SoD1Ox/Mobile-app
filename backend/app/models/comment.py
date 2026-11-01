"""Comment ORM model (auxiliary entity: recruiter note about a candidate)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.candidate import Candidate
    from app.models.user import User


class Comment(TimestampMixin, Base):
    __tablename__ = "comments"

    id: Mapped[int] = mapped_column(primary_key=True)
    text: Mapped[str] = mapped_column(String(2000), nullable=False)

    # many comments -> one candidate
    candidate_id: Mapped[int] = mapped_column(
        ForeignKey("candidates.id", ondelete="CASCADE"), index=True, nullable=False
    )
    candidate: Mapped["Candidate"] = relationship(back_populates="comments")

    # many comments -> one author (agency user)
    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    author: Mapped["User"] = relationship()

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Comment id={self.id} candidate_id={self.candidate_id}>"
