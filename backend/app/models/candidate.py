"""Candidate ORM model (main entity #2) — job seeker of the agency.

Relations:
    candidates <-> applications   (one-to-many)
    candidates <-> comments       (one-to-many, recruiter notes)
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.application import Application
    from app.models.comment import Comment


class Candidate(TimestampMixin, Base):
    __tablename__ = "candidates"

    id: Mapped[int] = mapped_column(primary_key=True)
    full_name: Mapped[str] = mapped_column(String(150), index=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    city: Mapped[str | None] = mapped_column(String(80), index=True, nullable=True)
    specialization: Mapped[str | None] = mapped_column(String(100), index=True, nullable=True)
    experience_years: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    resume_url: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # one candidate -> many applications to vacancies
    applications: Mapped[list["Application"]] = relationship(
        back_populates="candidate", cascade="all, delete-orphan"
    )
    # one candidate -> many recruiter comments/notes
    comments: Mapped[list["Comment"]] = relationship(
        back_populates="candidate", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Candidate id={self.id} full_name={self.full_name!r}>"
