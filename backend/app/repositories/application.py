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
from app.models.application import STATUS_SCORE, Application, ApplicationStatus
from app.repositories.base import BaseRepository


def _utcnow() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M")


class ApplicationRepository(
    BaseRepository[Application, ApplicationRead, ApplicationCreate, ApplicationUpdate]
):
    model = Application
    read_dto = ApplicationRead

    # ------------------------------------------------------------------ enrich
    @staticmethod
    def _enrich(session: Session, obj: Application) -> ApplicationRead:
        """Build ApplicationRead with denormalized display fields.

        Loads the related candidate / vacancy(+company) / users eagerly via
        ``session.get`` so the DTO carries everything a client needs to render
        a card without N+1 follow-up requests.
        """
        from app.models.candidate import Candidate
        from app.models.user import User
        from app.models.vacancy import Vacancy

        read = ApplicationRead.model_validate(obj, from_attributes=True)
        cand = session.get(Candidate, obj.candidate_id)
        if cand is not None:
            read.candidate_name = cand.full_name
        vac = session.get(Vacancy, obj.vacancy_id)
        if vac is not None:
            read.vacancy_title = vac.title
            read.salary_from = float(vac.salary_from) if vac.salary_from else None
            read.salary_to = float(vac.salary_to) if vac.salary_to else None
            if vac.company is not None:
                read.company_name = vac.company.name
        if obj.assigned_worker_id is not None:
            w = session.get(User, obj.assigned_worker_id)
            if w is not None:
                read.assigned_worker_name = w.full_name
        if obj.manager_id is not None:
            m = session.get(User, obj.manager_id)
            if m is not None:
                read.manager_name = m.full_name
        return read

    def get_by_id(self, entity_id: int) -> ApplicationRead | None:
        with Vis(self._factory) as session:
            obj = session.get(Application, entity_id)
            if obj is None:
                return None
            return self._enrich(session, obj)

    def create(self, data: ApplicationCreate) -> ApplicationRead:
        with Vis(self._factory) as session:
            obj = Application(**data.model_dump())
            session.add(obj)
            session.commit()
            session.refresh(obj)
            return self._enrich(session, obj)

    def update(self, entity_id: int, data: ApplicationUpdate) -> ApplicationRead | None:
        with Vis(self._factory) as session:
            obj = session.get(Application, entity_id)
            if obj is None:
                return None
            payload = data.model_dump(exclude_unset=True)
            new_status = payload.pop("status", None)
            for field, value in payload.items():
                setattr(obj, field, value)
            if new_status is not None and new_status != obj.status:
                # --- audit trail + self-learning funnel score -------------
                old = obj.status.value if hasattr(obj.status, "value") else str(obj.status)
                new = new_status.value if hasattr(new_status, "value") else str(new_status)
                actor = obj.assigned_worker_id or obj.manager_id
                entry = f"{old} -> {new} (by {actor or 'system'} @ {_utcnow()})"
                obj.prev_status = old
                obj.status_history = ((obj.status_history or "") + "\n" + entry).lstrip("\n")
                obj.completion_score = STATUS_SCORE[new_status]
                obj.status = new_status
            session.commit()
            session.refresh(obj)
            return self._enrich(session, obj)

    def search_paginated(
        self,
        params: PageParams,
        vacancy_id: int | None = None,
        candidate_id: int | None = None,
        status: ApplicationStatus | None = None,
        manager_id: int | None = None,
        assigned_worker_id: int | None = None,
    ) -> Page[ApplicationRead]:
        """Pagination + filtering by vacancy / candidate / pipeline status.

        Rows are loaded with joined relations (candidate, vacancy->company,
        responsible users) and returned as enriched DTOs — one request per
        page, no N+1 on the client side.
        """
        from sqlalchemy.orm import joinedload

        from app.models.vacancy import Vacancy

        with Vis(self._factory) as session:
            stmt = (
                select(Application)
                .options(
                    joinedload(Application.candidate),
                    joinedload(Application.vacancy).joinedload(Vacancy.company),
                    joinedload(Application.assigned_worker),
                    joinedload(Application.manager),
                )
            )
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
            if assigned_worker_id is not None:
                conditions.append(Application.assigned_worker_id == assigned_worker_id)

            for cond in conditions:
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Application] = session.scalars(
                stmt.order_by(Application.id.desc())
                .offset((params.page - 1) * params.page_size)
                .limit(params.page_size)
            ).unique().all()
            items = [self._enrich(session, r) for r in rows]
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
