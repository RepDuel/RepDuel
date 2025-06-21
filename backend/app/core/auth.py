# backend/app/core/auth.py

from fastapi import WebSocket, HTTPException, status
from jose import JWTError, jwt

from app.core.config import settings
from app.schemas.user import UserRead
from app.models.user import User
from app.db.session import async_session

async def get_current_user_ws(websocket: WebSocket, token: str) -> UserRead:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid JWT")

        async with async_session() as db:
            user = await db.get(User, user_id)
            if user is None:
                raise HTTPException(status_code=401, detail="User not found")
            return UserRead.model_validate(user)

    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
