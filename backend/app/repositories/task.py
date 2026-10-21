"""Task repository — all DB queries for the ``tasks`` table.

``tasks`` is the high-volume entity: every listing operation goes through
LIMIT/OFFSET pagination and eager-loading of tags (``selectinload``) so the
DTO conversion never triggers lazy loads after the session closes.
"""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, or_, select
from sqlalchemy.orm import selectinload

from app.db.vis import Vis
from app.dto.common import Page, PageParams
from app.dto.task import TaskCreate, TaskRead, TaskUpdate
from app.models.tag import Tag
from app.models.task import Task, TaskStatus
from app.repositories.base import BaseRepository


class TaskRepository(BaseRepository[Task, TaskRead, TaskCreate, TaskUpdate]):
    model = Task
    read_dto = TaskRead

    # ------------------------------------------------------------------ helpers
    def _base_query(self):
        return select(Task).options(selectinload(Task.tags))

    # ------------------------------------------------------------- list/search
    def search_paginated(
        self,
        params: PageParams,
        status: TaskStatus | None = None,
        project_id: int | None = None,
    ) -> Page[TaskRead]:
        """The main large-data mechanism: pagination + filtering + search."""
        with Vis(self._factory) as session:
            stmt = self._base_query()
            count_stmt = select(func.count()).select_from(Task)

            conditions = []
            if params.search:
                pattern = f"%{params.search.lower()}%"
                conditions.append(
                    or_(Task.title.ilike(pattern), Task.description.ilike(pattern))  # type: ignore[attr-defined]
                )
            if status is not None:
                conditions.append(Task.status == status)
            if project_id is not None:
                conditions.append(Task.project_id == project_id)

            for cond in conditions:
                stmt = stmt.where(cond)
                count_stmt = count_stmt.where(cond)

            total = session.scalar(count_stmt) or 0
            rows: Sequence[Task] = session.scalars(
                stmt.order_by(Task.id.desc())
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

    def get_with_tags(self, task_id: int) -> TaskRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(self._base_query().where(Task.id == task_id))
            return self._to_read(obj)

    def list_by_project(self, project_id: int) -> list[TaskRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Task] = session.scalars(
                self._base_query().where(Task.project_id == project_id).order_by(Task.id)
            ).all()
            return [self._to_read(r) for r in rows]  # type: ignore[misc]

    # ------------------------------------------------------------ create/update
    def create_with_tags(self, data: TaskCreate, tag_ids: list[int]) -> TaskRead:
        with Vis(self._factory) as session:
            payload = data.model_dump(exclude={"tag_ids"})
            obj = Task(**payload)
            if tag_ids:
                obj.tags = list(session.scalars(select(Tag).where(Tag.id.in_(tag_ids))))
            session.add(obj)
            session.flush()
            return TaskRead.model_validate(obj, from_attributes=True)

    def update_with_tags(self, task_id: int, data: TaskUpdate) -> TaskRead | None:
        payload = data.model_dump(exclude_unset=True, exclude={"tag_ids"})
        with Vis(self._factory) as session:
            obj = session.scalar(self._base_query().where(Task.id == task_id))
            if obj is None:
                return None
            for field, value in payload.items():
                setattr(obj, field, value)
            if data.tag_ids is not None:
                obj.tags = list(
                    session.scalars(select(Tag).where(Tag.id.in_(data.tag_ids)))
                )
            session.flush()
            return TaskRead.model_validate(obj, from_attributes=True)
