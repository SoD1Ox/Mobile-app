"""Repository layer: one repository class per entity, encapsulating all SQLAlchemy queries."""

from app.repositories.base import BaseRepository
from app.repositories.client import ClientRepository
from app.repositories.comment import CommentRepository
from app.repositories.contact import ContactRepository
from app.repositories.project import ProjectRepository
from app.repositories.tag import TagRepository
from app.repositories.task import TaskRepository
from app.repositories.user import UserRepository

__all__ = [
    "BaseRepository",
    "ClientRepository",
    "CommentRepository",
    "ContactRepository",
    "ProjectRepository",
    "TagRepository",
    "TaskRepository",
    "UserRepository",
]
