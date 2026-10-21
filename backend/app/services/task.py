"""Task service — business logic for the high-volume ``tasks`` entity."""

from __future__ import annotations

from app.dto.comment import CommentCreate, CommentRead
from app.dto.common import Page, PageParams
from app.dto.task import TaskCreate, TaskRead, TaskUpdate
from app.models.task import TaskStatus
from app.repositories.comment import CommentRepository
from app.repositories.project import ProjectRepository
from app.repositories.task import TaskRepository
from app.services.errors import NotFoundError, ValidationError


class TaskService:
    def __init__(
        self,
        repo: TaskRepository | None = None,
        project_repo: ProjectRepository | None = None,
        comment_repo: CommentRepository | None = None,
    ) -> None:
        self._repo = repo or TaskRepository()
        self._project_repo = project_repo or ProjectRepository()
        self._comment_repo = comment_repo or CommentRepository()

    # ------------------------------------------------------------- read/list
    def list_tasks(
        self,
        params: PageParams,
        status: TaskStatus | None = None,
        project_id: int | None = None,
    ) -> Page[TaskRead]:
        """Paginated + filtered listing (large-data mechanism)."""
        return self._repo.search_paginated(params, status=status, project_id=project_id)

    def get_task(self, task_id: int) -> TaskRead:
        task = self._repo.get_with_tags(task_id)
        if task is None:
            raise NotFoundError(f"Task {task_id} not found")
        return task

    # ---------------------------------------------------------------- write
    def create_task(self, data: TaskCreate, author_id: int) -> TaskRead:
        if not self._project_repo.exists(data.project_id):
            raise ValidationError(f"Project {data.project_id} does not exist")
        payload = data.model_copy(update={"author_id": author_id})
        return self._repo.create_with_tags(payload, tag_ids=payload.tag_ids)

    def update_task(self, task_id: int, data: TaskUpdate) -> TaskRead:
        self.get_task(task_id)  # 404 if missing
        if data.project_id is not None and not self._project_repo.exists(data.project_id):
            raise ValidationError(f"Project {data.project_id} does not exist")
        updated = self._repo.update_with_tags(task_id, data)
        if updated is None:
            raise NotFoundError(f"Task {task_id} not found")
        return updated

    def delete_task(self, task_id: int) -> None:
        if not self._repo.delete(task_id):
            raise NotFoundError(f"Task {task_id} not found")

    # -------------------------------------------------------------- comments
    def add_comment(self, task_id: int, data: CommentCreate, author_id: int) -> CommentRead:
        self.get_task(task_id)  # ensure task exists
        if data.task_id != task_id:
            raise ValidationError("task_id in body does not match path")
        return self._comment_repo.create_for_task(data, author_id=author_id)

    def list_comments(self, task_id: int) -> list[CommentRead]:
        self.get_task(task_id)
        return self._comment_repo.list_by_task(task_id)

    def delete_comment(self, comment_id: int) -> None:
        if not self._comment_repo.delete(comment_id):
            raise NotFoundError(f"Comment {comment_id} not found")
