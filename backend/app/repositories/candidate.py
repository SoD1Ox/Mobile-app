"""Candidate repository — all DB queries for the ``candidates`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, or_, select

from app.db.vis import Vis
from app.dto.candidate import CandidateCreate, CandidateRead, CandidateUpdate
from app.dto.common import Page, PageParams
from app.models.candidate import Candidate
from app.models.application import Application
from app.repositories.base import BaseRepository


class CandidateRepository(BaseRepository[Candidate, CandidateRead, CandidateCreate, CandidateUpdate]):
    model = Candidate
    read_dto = CandidateRead

    def search_paginated(
        self,
        params: PageParams,
        city: str | None = None,
        specialization: str | None = None,
        ids: list[int] | None = None,
    ) -> Page[CandidateRead]:
        """Pagination + ILIKE search over name / specialization / e-mail.

        ``ids`` restricts the query to an explicit id set (batch fetch used
        by clients that render cards for applications).
        """
        with Vis(self._factory) as session:
            stmt = select(Candidate)
            count_stmt = select(func.count()).select_from(Candidate)

            conditions = []
            if ids is not None:
                conditions.append(Candidate.id.in_(ids))
            if params.search:
                pattern = f"%{params.search.lower()}%"
                conditions.append(
                    or_(
                        Candidate.full_name.ilike(pattern),
                        Candidate.specialization.ilike(pattern),
                        Candidate.email.ilike(pattern),
                    )
                )
            if city:
                conditions.append(Candidate.city.ilike(f"%{city.lower()}%"))
            if specialization:
                conditions.append(Candidate.specialization.ilike(f"%{specialization.lower()}%"))

            for cond in conditions:
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Candidate] = session.scalars(
                stmt.order_by(Candidate.id.desc())
                .offset((params.page - 1) * params.page_size)
                .limit(params.page_size)
            ).all()
            items = [self._to_read(r) for r in rows]
            pages = (total + params.page_size - 1) // params.page_size
            return Page(
                items=items, total=total, page=params.page,
                page_size=params.page_size, pages=pages,
            )

    def get_by_email(self, email: str) -> CandidateRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(select(Candidate).where(Candidate.email == email))
            return self._to_read(obj)

    def has_assigned_application(self, candidate_id: int, worker_id: int) -> bool:
        """Check whether a worker may access a candidate through an assigned case."""
        with Vis(self._factory) as session:
            return session.scalar(
                select(Application.id)
                .where(
                    Application.candidate_id == candidate_id,
                    Application.assigned_worker_id == worker_id,
                )
                .limit(1)
            ) is not None
