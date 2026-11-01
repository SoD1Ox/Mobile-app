"""User ORM model (4th entity — security layer).

Passwords are stored ONLY as bcrypt hashes (``password_hash``); the plain-text
password never touches the database.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Enum as SAEnum, Float, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin

if TYPE_CHECKING:
    from app.models.application import Application

import enum


class UserRole(str, enum.Enum):
    ADMIN = "admin"          # администратор агентства
    MANAGER = "manager"      # кадровый менеджер / рекрутер
    WORKER = "worker"        # сотрудник (соискатель) с ограниченным доступом


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(120), unique=True, index=True, nullable=False)
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        SAEnum(UserRole, name="user_role", values_callable=lambda e: [m.value for m in e]), nullable=False, default=UserRole.WORKER
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    # Self-learning stat: moving average of funnel completion (0..1) over all
    # applications assigned to this user.  Updated on every status change.
    completion_score: Mapped[float | None] = mapped_column(Float, nullable=True)

    # A recruiter (manager) is responsible for many applications
    applications: Mapped[list["Application"]] = relationship(
        back_populates="manager", foreign_keys="Application.manager_id"
    )

    # A worker (executor) personally handles many assigned applications
    assigned_applications: Mapped[list["Application"]] = relationship(
        back_populates="assigned_worker", foreign_keys="Application.assigned_worker_id"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<User id={self.id} username={self.username!r} role={self.role}>"
