"""Project repository — all DB queries for the ``projects`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, select

from app.db.vis import Vis
from app.dto.common import Page, PageParams
from app.dto.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.models.project import Project
from app.repositories.base import BaseRepository


class ProjectRepository(BaseRepository[Project, ProjectRead, ProjectCreate, ProjectUpdate]):
    model = Project
    read_dto = ProjectRead

    def search_paginated(self, params: PageParams) -> Page[ProjectRead]:
        """Pagination + name/description ILIKE filter (large data friendly)."""
        with Vis(self._factory) as session:
            stmt = select(Project)
            count_stmt = select(func.count()).select_from(Project)
            if params.search:
                pattern = f"%{params.search.lower()}%"
                cond = Project.name.ilike(pattern) | Project.description.ilike(pattern)  # type: ignore[attr-defined]
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Project] = session.scalars(
                stmt.order_by(Project.id)
                .offset((params.page - 1) * params.page_size)
                .limit(params.page_size)
            ).all()
            items = [self._to_read(r) for r in rows]  # type: ignore[misc]
            pages = (total + params.page_size - 1) // params.page_size
            return Page(
                items=items,  # type: ignore[arg-type]
                total=total,
                page=params.page,
                page_size=params.page_size,
                pages=pages,
            )

    def list_by_client(self, client_id: int) -> list[ProjectRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Project] = session.scalars(
                select(Project).where(Project.client_id == client_id).order_by(Project.name)
            ).all()
            return [self._to_read(r) for r in rows]  # type: ignore[misc]
