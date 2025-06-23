import logging
from typing import Optional
from fastapi import WebSocket, HTTPException, status, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.schemas.user import UserRead
from app.models.user import User
from app.db.session import async_session
from app.services.user_service import get_user_by_id
from app.api.v1.deps import get_db

# Configure logging (adjust as needed; ideally configure once in main entrypoint)
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/users/login")


async def get_current_user_ws(websocket: WebSocket, token: str) -> Optional[UserRead]:
    try:
        logger.debug(f"WebSocket token received: {token}")
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        logger.debug(f"Decoded JWT payload: {payload}")
        user_id: Optional[str] = payload.get("sub")
        if user_id is None:
            logger.warning("JWT token does not contain 'sub' claim.")
            await websocket.close(code=1008)
            return None

        async with async_session() as db:
            user = await db.get(User, user_id)
            if user is None:
                logger.warning(f"User not found for id: {user_id}")
                await websocket.close(code=1008)
                return None
            return UserRead.model_validate(user)

    except JWTError as e:
        logger.warning(f"JWT decoding error in WebSocket auth: {e}")
        await websocket.close(code=1008)
        return None


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        logger.debug(f"Authorization token received: {token}")
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        logger.debug(f"Decoded JWT payload: {payload}")
        user_id: Optional[str] = payload.get("sub")
        if user_id is None:
            logger.warning("JWT token does not contain 'sub' claim.")
            raise credentials_exception
    except JWTError as e:
        logger.warning(f"JWT decoding error: {e}")
        raise credentials_exception

    user = await get_user_by_id(db, user_id)
    if user is None:
        logger.warning(f"User not found for id: {user_id}")
        raise credentials_exception
    return user
