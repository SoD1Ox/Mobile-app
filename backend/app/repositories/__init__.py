"""Repository layer: one repository class per entity, encapsulating all SQLAlchemy queries."""

from app.repositories.application import ApplicationRepository
from app.repositories.base import BaseRepository
from app.repositories.candidate import CandidateRepository
from app.repositories.comment import CommentRepository
from app.repositories.company import CompanyRepository
from app.repositories.contact import ContactRepository
from app.repositories.skill import SkillRepository
from app.repositories.user import UserRepository
from app.repositories.vacancy import VacancyRepository

__all__ = [
    "ApplicationRepository",
    "BaseRepository",
    "CandidateRepository",
    "CommentRepository",
    "CompanyRepository",
    "ContactRepository",
    "SkillRepository",
    "UserRepository",
    "VacancyRepository",
]
