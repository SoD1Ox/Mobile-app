"""Vacancy ORM model (main entity #1) — open position of a partner company.

A vacancy groups applications (candidates applying to it).

Relations:
    vacancies.company_id -> companies.id          (many-to-one)
    vacancies           <-> applications           (one-to-many)
"""

from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    Column,
    ForeignKey,
    Numeric,
    String,
    Table,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.application import Application
    from app.models.company import Company
    from app.models.skill import Skill


# Association table for the many-to-many relation vacancies <-> skills
vacancy_skills = Table(
    "vacancy_skills",
    Base.metadata,
    Column("vacancy_id", ForeignKey("vacancies.id", ondelete="CASCADE"), primary_key=True),
    Column("skill_id", ForeignKey("skills.id", ondelete="CASCADE"), primary_key=True),
)


class Vacancy(TimestampMixin, Base):
    __tablename__ = "vacancies"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200), index=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    salary_from: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    salary_to: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    city: Mapped[str | None] = mapped_column(String(80), index=True, nullable=True)
    remote: Mapped[bool] = mapped_column(default=False, nullable=False)

    # many vacancies -> one company
    company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"), index=True, nullable=False
    )
    company: Mapped["Company"] = relationship(back_populates="vacancies")

    # one vacancy -> many applications
    applications: Mapped[list["Application"]] = relationship(
        back_populates="vacancy", cascade="all, delete-orphan"
    )

    # many vacancies <-> many required skills (association table vacancy_skills)
    skills: Mapped[list["Skill"]] = relationship(
        secondary=vacancy_skills, back_populates="vacancies"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Vacancy id={self.id} title={self.title!r}>"
