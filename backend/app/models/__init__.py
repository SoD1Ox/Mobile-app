"""ORM models package.

Importing this module registers **all** mappers on ``Base.metadata`` — used by
Alembic autogenerate and by ``create_all`` in tests/seed scripts.

Database layout (7 tables + 1 association table, >= 5 relations):
    users, clients, projects, tasks, tags, contacts, comments, task_tags
"""

from app.db.base import Base
from app.models.client import Client
from app.models.comment import Comment
from app.models.contact import Contact
from app.models.mixins import TimestampMixin
from app.models.project import Project
from app.models.tag import Tag
from app.models.task import Task, TaskPriority, TaskStatus, task_tags
from app.models.user import User, UserRole

__all__ = [
    "Base",
    "Client",
    "Comment",
    "Contact",
    "Project",
    "Tag",
    "Task",
    "TaskPriority",
    "TaskStatus",
    "TimestampMixin",
    "User",
    "UserRole",
    "task_tags",
]
