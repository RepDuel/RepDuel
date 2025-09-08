# backend/app/core/security.py

from datetime import datetime, timedelta, timezone
from typing import Any, Union

from jose import jwt, JWTError
from passlib.context import CryptContext

from app.core.config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a plaintext password using bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a hashed version."""
    return pwd_context.verify(plain_password, hashed_password)


# ---------------------------
# ACCESS TOKENS
# ---------------------------
def create_access_token(
    data: dict[str, Any], expires_delta: Union[timedelta, None] = None
) -> str:
    """Generate a short-lived JWT access token."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


# ---------------------------
# REFRESH TOKENS
# ---------------------------

REFRESH_TOKEN_EXPIRE_DAYS = 30  # TikTok/Snapchat-style long sessions
JWT_REFRESH_SECRET_KEY = (
    settings.JWT_SECRET_KEY + "_refresh"
)  # derive a separate signing key


def create_refresh_token(
    data: dict[str, Any], expires_delta: Union[timedelta, None] = None
) -> str:
    """Generate a long-lived JWT refresh token."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode,
        JWT_REFRESH_SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


def verify_refresh_token(token: str) -> dict[str, Any]:
    """Decode and verify a refresh token. Raises JWTError if invalid/expired."""
    try:
        payload = jwt.decode(
            token,
            JWT_REFRESH_SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        return payload
    except JWTError as e:
        raise e
