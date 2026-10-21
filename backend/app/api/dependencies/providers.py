"""FastAPI dependency providers (composition root wiring).

Endpoints receive *services* via ``Depends`` — they never touch repositories,
sessions or ORM objects directly (architectural separation of concerns).
"""

from __future__ import annotations

from app.services.client import ClientService
from app.services.project import ProjectService
from app.services.task import TaskService
from app.services.user import UserService


def get_user_service() -> UserService:
    return UserService()


def get_project_service() -> ProjectService:
    return ProjectService()


def get_task_service() -> TaskService:
    return TaskService()


def get_client_service() -> ClientService:
    return ClientService()
