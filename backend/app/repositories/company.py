"""Company repository — all DB queries for the ``companies`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, or_, select

from app.db.vis import Vis
from app.dto.common import Page, PageParams
from app.dto.company import CompanyCreate, CompanyRead, CompanyUpdate
from app.models.company import Company
from app.repositories.base import BaseRepository


class CompanyRepository(BaseRepository[Company, CompanyRead, CompanyCreate, CompanyUpdate]):
    model = Company
    read_dto = CompanyRead

    def search_paginated(self, params: PageParams) -> Page[CompanyRead]:
        """Pagination + ILIKE search over name / industry (large-data handling)."""
        with Vis(self._factory) as session:
            stmt = select(Company)
            count_stmt = select(func.count()).select_from(Company)
            if params.search:
                pattern = f"%{params.search.lower()}%"
                cond = or_(Company.name.ilike(pattern), Company.industry.ilike(pattern))
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)
            total = session.scalar(count_stmt) or 0
            rows: Sequence[Company] = session.scalars(
                stmt.order_by(Company.name).offset((params.page - 1) * params.page_size).limit(
                    params.page_size
                )
            ).all()
            items = [self._to_read(r) for r in rows]
            pages = (total + params.page_size - 1) // params.page_size
            return Page(
                items=items, total=total, page=params.page,
                page_size=params.page_size, pages=pages,
            )
