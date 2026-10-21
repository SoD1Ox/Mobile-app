"""User service — business logic for the 4th (security) entity.

Responsibilities: registration, authentication (JWT pair issuing), token refresh,
admin CRUD over users. Passwords are hashed before hitting the repository.
"""

from __future__ import annotations

import jwt as pyjwt

from app.dto.auth import TokenPair
from app.dto.user import UserCreate, UserRead, UserRegister, UserUpdate
from app.models.user import UserRole
from app.repositories.user import UserRepository
from app.security.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.services.errors import (
    AuthenticationError,
    ConflictError,
    NotFoundError,
    PermissionDeniedError,
)


class UserService:
    def __init__(self, repo: UserRepository | None = None) -> None:
        self._repo = repo or UserRepository()

    # ------------------------------------------------------------- auth flow
    def register(self, data: UserRegister) -> TokenPair:
        """Public self-registration; role is always forced to WORKER."""
        if self._repo.get_by_username(data.username):
            raise ConflictError("Username already taken")
        if self._repo.get_by_email(data.email):
            raise ConflictError("Email already registered")

        payload = UserCreate(
            username=data.username,
            email=data.email,
            full_name=data.full_name,
            role=UserRole.WORKER,
            is_active=True,
            password=data.password,
        )
        user = self._create_internal(payload)
        return self._token_pair(user)

    def login(self, username: str, password: str) -> TokenPair:
        user = self._repo.get_by_username(username)
        if user is None:
            # Same message as bad password — do not leak which half failed.
            raise AuthenticationError("Invalid username or password")
        # The hash lives only inside this method scope (never in DTOs).
        stored_hash = self._repo.get_password_hash(user.id)
        if not stored_hash or not verify_password(password, stored_hash):
            raise AuthenticationError("Invalid username or password")
        if not user.is_active:
            raise PermissionDeniedError("Account is deactivated")
        return self._token_pair(user)

    def refresh(self, refresh_token: str) -> TokenPair:
        try:
            payload = decode_token(refresh_token, expected_type="refresh")
        except pyjwt.PyJWTError as exc:
            raise AuthenticationError(f"Invalid refresh token: {exc}") from exc
        user = self._repo.get_by_id(payload.sub)
        if user is None or not user.is_active:
            raise AuthenticationError("User no longer exists or is deactivated")
        return self._token_pair(user)

    # ---------------------------------------------------------------- CRUD
    def list_users(self) -> list[UserRead]:
        return self._repo.list_all()

    def search(self, keyword: str) -> list[UserRead]:
        return self._repo.search(keyword)

    def get_user(self, user_id: int) -> UserRead:
        user = self._repo.get_by_id(user_id)
        if user is None:
            raise NotFoundError(f"User {user_id} not found")
        return user

    def create_user(self, data: UserCreate) -> UserRead:
        """Admin-only creation with explicit role."""
        if self._repo.get_by_username(data.username):
            raise ConflictError("Username already taken")
        if self._repo.get_by_email(data.email):
            raise ConflictError("Email already registered")
        return self._create_internal(data)

    def update_user(self, user_id: int, data: UserUpdate) -> UserRead:
        existing = self._repo.get_by_id(user_id)
        if existing is None:
            raise NotFoundError(f"User {user_id} not found")
        if data.username and data.username != existing.username:
            if self._repo.get_by_username(data.username):
                raise ConflictError("Username already taken")
        if data.email and data.email != existing.email:
            if self._repo.get_by_email(data.email):
                raise ConflictError("Email already registered")

        payload = data.model_dump(exclude_unset=True)
        password = payload.pop("password", None)
        if password:
            payload["password_hash"] = hash_password(password)
        updated = self._repo.update_fields(user_id, payload)
        if updated is None:
            raise NotFoundError(f"User {user_id} not found")
        return updated

    def deactivate_user(self, user_id: int) -> UserRead:
        """Soft delete: flip ``is_active`` off (history of tasks stays intact)."""
        user = self._repo.get_by_id(user_id)
        if user is None:
            raise NotFoundError(f"User {user_id} not found")
        result = self._repo.update_fields(user_id, {"is_active": False})
        assert result is not None
        return result

    def delete_user(self, user_id: int) -> None:
        if not self._repo.delete(user_id):
            raise NotFoundError(f"User {user_id} not found")

    # -------------------------------------------------------------- internal
    def _create_internal(self, data: UserCreate) -> UserRead:
        plain = data.password
        fields = data.model_dump(exclude={"password"})
        return self._repo.create_with_fields(fields, hash_password(plain))

    @staticmethod
    def _token_pair(user: UserRead) -> TokenPair:
        return TokenPair(
            access_token=create_access_token(user.id, user.role),
            refresh_token=create_refresh_token(user.id, user.role),
        )
