"""Company ORM model — client company of the staffing agency.

Relations:
    companies <-> vacancies   (one-to-many)
    companies <-> contacts    (one-to-many, contact persons of the company)
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.contact import Contact
    from app.models.vacancy import Vacancy


class Company(TimestampMixin, Base):
    __tablename__ = "companies"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150), index=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    industry: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # one company -> many vacancies
    vacancies: Mapped[list["Vacancy"]] = relationship(back_populates="company")
    # one company -> many contact persons
    contacts: Mapped[list["Contact"]] = relationship(
        back_populates="company", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Company id={self.id} name={self.name!r}>"
