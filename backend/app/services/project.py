"""Project service — business logic between API and ProjectRepository."""

from __future__ import annotations

from app.dto.common import Page, PageParams
from app.dto.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.repositories.client import ClientRepository
from app.repositories.project import ProjectRepository
from app.services.errors import NotFoundError, ValidationError


class ProjectService:
    def __init__(
        self,
        repo: ProjectRepository | None = None,
        client_repo: ClientRepository | None = None,
    ) -> None:
        self._repo = repo or ProjectRepository()
        self._client_repo = client_repo or ClientRepository()

    def list_projects(self, params: PageParams) -> Page[ProjectRead]:
        return self._repo.search_paginated(params)

    def get_project(self, project_id: int) -> ProjectRead:
        project = self._repo.get_by_id(project_id)
        if project is None:
            raise NotFoundError(f"Project {project_id} not found")
        return project

    def create_project(self, data: ProjectCreate) -> ProjectRead:
        if not self._client_repo.exists(data.client_id):
            raise ValidationError(f"Client {data.client_id} does not exist")
        return self._repo.create(data)

    def update_project(self, project_id: int, data: ProjectUpdate) -> ProjectRead:
        self.get_project(project_id)  # 404 if missing
        if data.client_id is not None and not self._client_repo.exists(data.client_id):
            raise ValidationError(f"Client {data.client_id} does not exist")
        updated = self._repo.update(project_id, data)
        if updated is None:
            raise NotFoundError(f"Project {project_id} not found")
        return updated

    def delete_project(self, project_id: int) -> None:
        if not self._repo.delete(project_id):
            raise NotFoundError(f"Project {project_id} not found")

    def list_by_client(self, client_id: int) -> list[ProjectRead]:
        if not self._client_repo.exists(client_id):
            raise NotFoundError(f"Client {client_id} not found")
        return self._repo.list_by_client(client_id)
