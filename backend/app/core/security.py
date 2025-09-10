# backend/app/core/security.py

from datetime import datetime, timedelta, timezone
from typing import Any, Union

from jose import jwt, JWTError
from passlib.context import CryptContext

from app.core.config import settings

# -----------------------------------------------------------------------------
# Password hashing
# -----------------------------------------------------------------------------

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a plaintext password using bcrypt."""
    return _pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a bcrypt hash."""
    return _pwd_context.verify(plain_password, hashed_password)


# -----------------------------------------------------------------------------
# JWT helpers
# -----------------------------------------------------------------------------

def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(
    data: dict[str, Any],
    expires_delta: Union[timedelta, None] = None,
) -> str:
    """
    Create a short-lived access token.
    Uses settings.JWT_SECRET_KEY and settings.ACCESS_TOKEN_EXPIRE_MINUTES.
    Adds standard claims: exp, iat, and typ="access".
    """
    to_encode = data.copy()
    expire = _utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update(
        {
            "exp": expire,
            "iat": _utcnow(),
            "typ": "access",
        }
    )
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )


def create_refresh_token(
    data: dict[str, Any],
    expires_delta: Union[timedelta, None] = None,
) -> str:
    """
    Create a long-lived refresh token.
    Uses settings.JWT_REFRESH_SECRET_KEY and settings.REFRESH_TOKEN_EXPIRE_DAYS.
    Adds standard claims: exp, iat, and typ="refresh".
    """
    to_encode = data.copy()
    expire = _utcnow() + (expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))
    to_encode.update(
        {
            "exp": expire,
            "iat": _utcnow(),
            "typ": "refresh",
        }
    )
    return jwt.encode(
        to_encode,
        settings.JWT_REFRESH_SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )


def verify_refresh_token(token: str) -> dict[str, Any]:
    """
    Decode & verify a refresh token.
    - Verifies signature with settings.JWT_REFRESH_SECRET_KEY
    - Verifies exp
    - Ensures typ == "refresh"
    Raises JWTError if invalid/expired.
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_REFRESH_SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        token_type = payload.get("typ")
        if token_type and token_type != "refresh":
            # Maintain consistency with your /users/refresh check
            raise JWTError("Invalid token type")
        return payload
    except JWTError as e:
        # Surface JWTError so callers can translate to HTTP 401/403 as needed
        raise e
