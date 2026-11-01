"""DTO (pydantic schema) layer.

Protective layer between the ORM (SQLAlchemy models) and the API/UI:
DTOs contain only the data the interface needs, have no session binding and
no lazy-loaded attributes — so a closed session can never raise
``DetachedInstanceError`` through them.
"""

from app.dto.application import ApplicationCreate, ApplicationRead, ApplicationUpdate
from app.dto.auth import TokenPair, TokenPayload
from app.dto.candidate import CandidateCreate, CandidateRead, CandidateUpdate
from app.dto.comment import CommentCreate, CommentRead
from app.dto.common import Page, PageParams
from app.dto.company import CompanyCreate, CompanyRead, CompanyUpdate
from app.dto.contact import ContactCreate, ContactRead, ContactUpdate
from app.dto.skill import SkillCreate, SkillRead
from app.dto.user import UserCreate, UserLogin, UserRead, UserRegister, UserUpdate
from app.dto.vacancy import VacancyCreate, VacancyRead, VacancyUpdate

__all__ = [
    "ApplicationCreate",
    "ApplicationRead",
    "ApplicationUpdate",
    "CandidateCreate",
    "CandidateRead",
    "CandidateUpdate",
    "CommentCreate",
    "CommentRead",
    "CompanyCreate",
    "CompanyRead",
    "CompanyUpdate",
    "ContactCreate",
    "ContactRead",
    "ContactUpdate",
    "Page",
    "PageParams",
    "SkillCreate",
    "SkillRead",
    "TokenPair",
    "TokenPayload",
    "UserCreate",
    "UserLogin",
    "UserRead",
    "UserRegister",
    "UserUpdate",
    "VacancyCreate",
    "VacancyRead",
    "VacancyUpdate",
]
