"""User repository — encapsulates all DB queries for the ``users`` table."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import or_, select

from app.db.vis import Vis
from app.dto.user import UserCreate, UserRead, UserUpdate
from app.models.user import User
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User, UserRead, UserCreate, UserUpdate]):
    model = User
    read_dto = UserRead

    # ------------------------------------------------------------ extra queries
    def get_by_username(self, username: str) -> UserRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(select(User).where(User.username == username))
            return self._to_read(obj)

    def get_by_email(self, email: str) -> UserRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(select(User).where(User.email == email))
            return self._to_read(obj)

    def search(self, keyword: str) -> list[UserRead]:
        """Search by username / e-mail / full name (case-insensitive)."""
        pattern = f"%{keyword.lower()}%"
        with Vis(self._factory) as session:
            rows: Sequence[User] = session.scalars(
                select(User)
                .where(
                    or_(
                        User.username.ilike(pattern),
                        User.email.ilike(pattern),
                        User.full_name.ilike(pattern),
                    )
                )
                .order_by(User.username)
            ).all()
            return [self._to_read(r) for r in rows]  # type: ignore[misc]

    # ------------------------------------- password-aware helpers (security)
    def get_password_hash(self, user_id: int) -> str | None:
        """Return the stored bcrypt hash (used only inside the service layer)."""
        with Vis(self._factory) as session:
            obj = session.get(User, user_id)
            return obj.password_hash if obj else None

    def create_with_hash(self, data: UserCreate, password_hash: str) -> UserRead:
        """Create a user from a full DTO (with plain password dropped) + hash."""
        fields = data.model_dump(exclude={"password"})
        return self.create_with_fields(fields, password_hash)

    def create_with_fields(self, fields: dict, password_hash: str) -> UserRead:
        """Create a user from raw column fields + pre-computed bcrypt hash."""
        with Vis(self._factory) as session:
            obj = User(**fields, password_hash=password_hash)
            session.add(obj)
            session.flush()
            return UserRead.model_validate(obj, from_attributes=True)

    def update_fields(self, user_id: int, fields: dict) -> UserRead | None:
        """Apply arbitrary column updates (e.g. ``password_hash``/``is_active``)."""
        with Vis(self._factory) as session:
            obj = session.get(User, user_id)
            if obj is None:
                return None
            for key, value in fields.items():
                setattr(obj, key, value)
            session.flush()
            return UserRead.model_validate(obj, from_attributes=True)
