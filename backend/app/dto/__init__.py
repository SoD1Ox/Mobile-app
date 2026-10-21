"""DTO (pydantic schema) layer.

Protective layer between the ORM (SQLAlchemy models) and the API/UI:
DTOs contain only the data the interface needs, have no session binding and
no lazy-loaded attributes — so a closed session can never raise
``DetachedInstanceError`` through them.
"""

from app.dto.common import Page, PageParams
from app.dto.user import (
    UserCreate,
    UserLogin,
    UserRead,
    UserRegister,
    UserUpdate,
)
from app.dto.auth import TokenPair, TokenPayload
from app.dto.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.dto.task import TaskCreate, TaskRead, TaskUpdate
from app.dto.client import ClientCreate, ClientRead, ClientUpdate
from app.dto.tag import TagRead
from app.dto.comment import CommentCreate, CommentRead
from app.dto.contact import ContactCreate, ContactRead, ContactUpdate

__all__ = [
    "Page",
    "PageParams",
    "TokenPair",
    "TokenPayload",
    "UserCreate",
    "UserLogin",
    "UserRead",
    "UserRegister",
    "UserUpdate",
    "ProjectCreate",
    "ProjectRead",
    "ProjectUpdate",
    "TaskCreate",
    "TaskRead",
    "TaskUpdate",
    "ClientCreate",
    "ClientRead",
    "ClientUpdate",
    "TagRead",
    "CommentCreate",
    "CommentRead",
    "ContactCreate",
    "ContactRead",
    "ContactUpdate",
]
