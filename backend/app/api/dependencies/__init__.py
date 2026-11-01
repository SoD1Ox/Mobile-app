"""API dependency layer."""

from app.api.dependencies.auth import (
    AdminUser,
    CurrentUser,
    ManagerOrAdmin,
    get_current_user,
    require_roles,
)
from app.api.dependencies.providers import (
    get_application_service,
    get_candidate_service,
    get_company_service,
    get_skill_service,
    get_user_service,
    get_vacancy_service,
)

__all__ = [
    "AdminUser",
    "CurrentUser",
    "ManagerOrAdmin",
    "get_application_service",
    "get_candidate_service",
    "get_company_service",
    "get_current_user",
    "get_skill_service",
    "get_user_service",
    "get_vacancy_service",
    "require_roles",
]
