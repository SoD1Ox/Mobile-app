"""API dependency layer."""

from app.api.dependencies.auth import (
    AdminUser,
    CurrentUser,
    ManagerOrAdmin,
    get_current_user,
    require_roles,
)
from app.api.dependencies.providers import (
    get_client_service,
    get_project_service,
    get_task_service,
    get_user_service,
)

__all__ = [
    "AdminUser",
    "CurrentUser",
    "ManagerOrAdmin",
    "get_client_service",
    "get_current_user",
    "get_project_service",
    "get_task_service",
    "get_user_service",
    "require_roles",
]
