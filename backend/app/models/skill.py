"""Skill ORM model (auxiliary entity, many-to-many with vacancies)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.vacancy import Vacancy  # noqa: F401


class Skill(Base):
    __tablename__ = "skills"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

    # many skills <-> many vacancies (association table vacancy_skills)
    vacancies: Mapped[list["Vacancy"]] = relationship(
        secondary="vacancy_skills", back_populates="skills"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Skill id={self.id} name={self.name!r}>"
