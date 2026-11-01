"""ORM models package.

Importing this module registers **all** mappers on ``Base.metadata`` — used by
Alembic autogenerate and by ``create_all`` in tests/seed scripts.

Database layout of the staffing agency (7 tables + 1 association table):
    users, companies, vacancies, candidates, applications, skills, contacts,
    comments, vacancy_skills
"""

from app.db.base import Base
from app.models.application import Application, ApplicationStatus
from app.models.candidate import Candidate
from app.models.comment import Comment
from app.models.company import Company
from app.models.contact import Contact
from app.models.mixins import TimestampMixin
from app.models.skill import Skill
from app.models.user import User, UserRole
from app.models.vacancy import Vacancy, vacancy_skills

__all__ = [
    "Application",
    "ApplicationStatus",
    "Base",
    "Candidate",
    "Comment",
    "Company",
    "Contact",
    "Skill",
    "TimestampMixin",
    "User",
    "UserRole",
    "Vacancy",
    "vacancy_skills",
]
