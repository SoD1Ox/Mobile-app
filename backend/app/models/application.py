"""Application ORM model (main entity #3) — a candidate applying to a vacancy.

This is the high-volume junction entity of the staffing domain
(candidate x vacancy + status pipeline).

Relations:
    applications.candidate_id -> candidates.id   (many-to-one)
    applications.vacancy_id   -> vacancies.id    (many-to-one)
    applications.manager_id   -> users.id        (many-to-one, responsible recruiter)
"""

from __future__ import annotations

import enum
from typing import TYPE_CHECKING

from sqlalchemy import Enum as SAEnum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.candidate import Candidate
    from app.models.user import User
    from app.models.vacancy import Vacancy


class ApplicationStatus(str, enum.Enum):
    NEW = "new"                    # отклик получен
    REVIEW = "review"              # резюме изучается
    INTERVIEW = "interview"        # назначено/проведено интервью
    OFFER = "offer"                # оффер предложен
    HIRED = "hired"                # кандидат трудоустроен
    REJECTED = "rejected"          # отказ


class Application(TimestampMixin, Base):
    __tablename__ = "applications"
    __table_args__ = (
        # a candidate can apply to the same vacancy only once
        UniqueConstraint("candidate_id", "vacancy_id", name="uq_application_candidate_vacancy"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    status: Mapped[ApplicationStatus] = mapped_column(
        SAEnum(
            ApplicationStatus,
            name="application_status",
            values_callable=lambda e: [m.value for m in e],
        ),
        nullable=False,
        default=ApplicationStatus.NEW,
        index=True,
    )

    # many applications -> one candidate
    candidate_id: Mapped[int] = mapped_column(
        ForeignKey("candidates.id", ondelete="CASCADE"), index=True, nullable=False
    )
    candidate: Mapped["Candidate"] = relationship(back_populates="applications")

    # many applications -> one vacancy
    vacancy_id: Mapped[int] = mapped_column(
        ForeignKey("vacancies.id", ondelete="CASCADE"), index=True, nullable=False
    )
    vacancy: Mapped["Vacancy"] = relationship(back_populates="applications")

    # many applications -> one responsible recruiter (agency manager)
    manager_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True, nullable=True
    )
    manager: Mapped["User | None"] = relationship(back_populates="applications")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Application id={self.id} c={self.candidate_id} v={self.vacancy_id} {self.status}>"
