"""Security utilities: password hashing (bcrypt) and JWT token creation/decoding.

Passwords are stored **only** as bcrypt hashes; plain text never reaches the DB.
Access/refresh tokens are signed JWTs carrying ``sub`` (user id), ``role`` and ``type``.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config.settings import settings
from app.dto.auth import TokenPayload
from app.models.user import UserRole


# --------------------------------------------------------------- passwords
def _prepare(plain: str) -> bytes:
    """bcrypt uses at most 72 bytes of the password — truncate explicitly."""
    return plain.encode("utf-8")[:72]


def hash_password(plain: str) -> str:
    """Return a bcrypt hash of the plain-text password."""
    return bcrypt.hashpw(_prepare(plain), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Constant-time verification of a password against its bcrypt hash."""
    try:
        return bcrypt.checkpw(_prepare(plain), hashed.encode("utf-8"))
    except ValueError:
        return False


# --------------------------------------------------------------------- JWT
def _create_token(user_id: int, role: UserRole, token_type: str, lifetime: timedelta) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role.value,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + lifetime).timestamp()),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def create_access_token(user_id: int, role: UserRole) -> str:
    return _create_token(
        user_id, role, "access", timedelta(minutes=settings.access_token_expire_minutes)
    )


def create_refresh_token(user_id: int, role: UserRole) -> str:
    return _create_token(
        user_id, role, "refresh", timedelta(days=settings.refresh_token_expire_days)
    )


def decode_token(token: str, expected_type: str) -> TokenPayload:
    """Decode & validate a JWT; raise ``jwt.PyJWTError`` on any problem."""
    raw = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
    if raw.get("type") != expected_type:
        raise jwt.InvalidTokenError(f"expected {expected_type} token")
    return TokenPayload(sub=int(raw["sub"]), role=UserRole(raw["role"]), type=raw["type"])
