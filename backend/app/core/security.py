# backend/app/core/security.py

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Union

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(data: Dict[str, Any], expires_delta: Union[timedelta, None] = None) -> str:
    to_encode = data.copy()
    expire = _utc_now() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(data: Dict[str, Any], expires_delta: Union[timedelta, None] = None) -> str:
    to_encode = data.copy()
    expire = _utc_now() + (expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))
    to_encode.update({"exp": expire, "type": "refresh"})
    secret = settings.REFRESH_JWT_SECRET_KEY or settings.JWT_SECRET_KEY
    return jwt.encode(to_encode, secret, algorithm=settings.ALGORITHM)


def decode_refresh_token(token: str) -> Dict[str, Any]:
    secret = settings.REFRESH_JWT_SECRET_KEY or settings.JWT_SECRET_KEY
    payload = jwt.decode(token, secret, algorithms=[settings.ALGORITHM])
    if payload.get("type") != "refresh":
        raise JWTError("Invalid token type")
    return payload
