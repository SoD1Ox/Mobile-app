"""FastAPI dependency providers (composition root wiring).

Endpoints receive *services* via ``Depends`` — they never touch repositories,
sessions or ORM objects directly (architectural separation of concerns).
"""

from __future__ import annotations

from app.services.application import ApplicationService
from app.services.candidate import CandidateService
from app.services.company import CompanyService
from app.services.contact import ContactService
from app.services.skill import SkillService
from app.services.user import UserService
from app.services.vacancy import VacancyService


def get_user_service() -> UserService:
    return UserService()


def get_company_service() -> CompanyService:
    return CompanyService()


def get_vacancy_service() -> VacancyService:
    return VacancyService()


def get_candidate_service() -> CandidateService:
    return CandidateService()


def get_application_service() -> ApplicationService:
    return ApplicationService()


def get_skill_service() -> SkillService:
    return SkillService()


def get_contact_service() -> ContactService:
    return ContactService()
