"""Vacancy repository — all DB queries for the ``vacancies`` table.

Eager-loads required skills via ``selectinload`` so DTO conversion never
triggers a lazy load after the session is closed.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Sequence

from sqlalchemy import func, or_, select
from sqlalchemy.orm import selectinload

from app.db.vis import Vis
from app.dto.common import Page, PageParams
from app.dto.vacancy import VacancyCreate, VacancyRead, VacancyUpdate
from app.models.skill import Skill
from app.models.vacancy import Vacancy
from app.repositories.base import BaseRepository


class VacancyRepository(BaseRepository[Vacancy, VacancyRead, VacancyCreate, VacancyUpdate]):
    model = Vacancy
    read_dto = VacancyRead

    def _base_query(self):
        return select(Vacancy).options(selectinload(Vacancy.skills))

    # ------------------------------------------------------------- list/search
    def search_paginated(
        self,
        params: PageParams,
        company_id: int | None = None,
        city: str | None = None,
        remote: bool | None = None,
        salary_min: Decimal | None = None,
        ids: list[int] | None = None,
    ) -> Page[VacancyRead]:
        """The main large-data mechanism: pagination + filtering + search.

        ``ids`` restricts to an explicit id set (batch fetch by clients)."""
        with Vis(self._factory) as session:
            stmt = self._base_query()
            count_stmt = select(func.count()).select_from(Vacancy)

            conditions = []
            if ids is not None:
                conditions.append(Vacancy.id.in_(ids))
            if params.search:
                pattern = f"%{params.search.lower()}%"
                conditions.append(
                    or_(Vacancy.title.ilike(pattern), Vacancy.description.ilike(pattern))
                )
            if company_id is not None:
                conditions.append(Vacancy.company_id == company_id)
            if city:
                conditions.append(Vacancy.city.ilike(f"%{city.lower()}%"))
            if remote is not None:
                conditions.append(Vacancy.remote == remote)
            if salary_min is not None:
                conditions.append(
                    or_(Vacancy.salary_from >= salary_min, Vacancy.salary_to >= salary_min)
                )

            for cond in conditions:
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Vacancy] = session.scalars(
                stmt.order_by(Vacancy.id.desc())
                .offset((params.page - 1) * params.page_size)
                .limit(params.page_size)
            ).all()
            items = [self._to_read(r) for r in rows]
            pages = (total + params.page_size - 1) // params.page_size
            return Page(
                items=items, total=total, page=params.page,
                page_size=params.page_size, pages=pages,
            )

    def get_with_skills(self, vacancy_id: int) -> VacancyRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(self._base_query().where(Vacancy.id == vacancy_id))
            return self._to_read(obj)

    def list_by_company(self, company_id: int) -> list[VacancyRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Vacancy] = session.scalars(
                self._base_query().where(Vacancy.company_id == company_id).order_by(Vacancy.id)
            ).all()
            return [self._to_read(r) for r in rows]

    # ------------------------------------------------------------ create/update
    def create_with_skills(self, data: VacancyCreate, skill_ids: list[int]) -> VacancyRead:
        with Vis(self._factory) as session:
            payload = data.model_dump(exclude={"skill_ids"})
            obj = Vacancy(**payload)
            if skill_ids:
                obj.skills = list(session.scalars(select(Skill).where(Skill.id.in_(skill_ids))))
            session.add(obj)
            session.flush()
            return VacancyRead.model_validate(obj, from_attributes=True)

    def update_with_skills(self, vacancy_id: int, data: VacancyUpdate) -> VacancyRead | None:
        payload = data.model_dump(exclude_unset=True, exclude={"skill_ids"})
        with Vis(self._factory) as session:
            obj = session.scalar(self._base_query().where(Vacancy.id == vacancy_id))
            if obj is None:
                return None
            for field, value in payload.items():
                setattr(obj, field, value)
            if data.skill_ids is not None:
                obj.skills = list(session.scalars(select(Skill).where(Skill.id.in_(data.skill_ids))))
            session.flush()
            return VacancyRead.model_validate(obj, from_attributes=True)
