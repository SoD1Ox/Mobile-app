"""Application repository — all DB queries for the ``applications`` table.

``applications`` is the high-volume junction entity (candidate x vacancy):
every listing goes through LIMIT/OFFSET pagination.
"""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, select

from app.db.vis import Vis
from app.dto.application import ApplicationCreate, ApplicationRead, ApplicationUpdate
from app.dto.common import Page, PageParams
from app.models.application import Application, ApplicationStatus
from app.repositories.base import BaseRepository


class ApplicationRepository(
    BaseRepository[Application, ApplicationRead, ApplicationCreate, ApplicationUpdate]
):
    model = Application
    read_dto = ApplicationRead

    def search_paginated(
        self,
        params: PageParams,
        vacancy_id: int | None = None,
        candidate_id: int | None = None,
        status: ApplicationStatus | None = None,
        manager_id: int | None = None,
    ) -> Page[ApplicationRead]:
        """Pagination + filtering by vacancy / candidate / pipeline status."""
        with Vis(self._factory) as session:
            stmt = select(Application)
            count_stmt = select(func.count()).select_from(Application)

            conditions = []
            if vacancy_id is not None:
                conditions.append(Application.vacancy_id == vacancy_id)
            if candidate_id is not None:
                conditions.append(Application.candidate_id == candidate_id)
            if status is not None:
                conditions.append(Application.status == status)
            if manager_id is not None:
                conditions.append(Application.manager_id == manager_id)

            for cond in conditions:
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Application] = session.scalars(
                stmt.order_by(Application.id.desc())
                .offset((params.page - 1) * params.page_size)
                .limit(params.page_size)
            ).all()
            items = [self._to_read(r) for r in rows]
            pages = (total + params.page_size - 1) // params.page_size
            return Page(
                items=items, total=total, page=params.page,
                page_size=params.page_size, pages=pages,
            )

    def exists_pair(self, candidate_id: int, vacancy_id: int) -> bool:
        """A candidate may apply to the same vacancy only once (unique pair)."""
        with Vis(self._factory) as session:
            return (
                session.scalar(
                    select(func.count())
                    .select_from(Application)
                    .where(
                        Application.candidate_id == candidate_id,
                        Application.vacancy_id == vacancy_id,
                    )
                )
                or 0
            ) > 0

    def list_by_vacancy(self, vacancy_id: int) -> list[ApplicationRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Application] = session.scalars(
                select(Application)
                .where(Application.vacancy_id == vacancy_id)
                .order_by(Application.id)
            ).all()
            return [self._to_read(r) for r in rows]

    def list_by_candidate(self, candidate_id: int) -> list[ApplicationRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Application] = session.scalars(
                select(Application)
                .where(Application.candidate_id == candidate_id)
                .order_by(Application.id)
            ).all()
            return [self._to_read(r) for r in rows]
