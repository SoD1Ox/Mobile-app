"""Tag ORM model (auxiliary entity, many-to-many with tasks)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.task import Task, task_tags  # noqa: F401


class Tag(Base):
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

    # many tags <-> many tasks (association table task_tags)
    tasks: Mapped[list["Task"]] = relationship(
        secondary="task_tags", back_populates="tags"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Tag id={self.id} name={self.name!r}>"
