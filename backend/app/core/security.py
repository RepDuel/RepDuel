# backend/app/core/security.py

from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import jwt
from typing import Any, Union

from app.core.config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    """Hash a plaintext password using bcrypt."""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a hashed version."""
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(
    data: dict[str, Any],
    expires_delta: Union[timedelta, None] = None
) -> str:
    """Generate a JWT access token with UTC expiration timestamp."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt
