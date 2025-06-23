# backend/app/api/v1/websockets.py

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from uuid import UUID
import json

from app.core.auth import get_current_user_ws
from app.services.message_service import create_message
from app.schemas.message import MessageCreate, MessageRead
from app.db.session import async_session
from app.services.websocket_manager import WebSocketManager  # import your manager

router = APIRouter()
ws_manager = WebSocketManager()  # instantiate your manager

@router.websocket("/ws/{channel_id}")
async def websocket_chat(
    websocket: WebSocket,
    channel_id: UUID,
    token: str = Query(...)
):
    user = await get_current_user_ws(websocket, token)
    if not user:
        await websocket.close(code=1008)
        return

    await ws_manager.connect(websocket, channel_id)

    try:
        while True:
            text = await websocket.receive_text()

            async with async_session() as db:
                message = await create_message(
                    db=db,
                    message_in=MessageCreate(content=text, channel_id=channel_id),
                    author_id=user.id,
                )
                message_data = MessageRead.from_orm(message).dict()

            await ws_manager.broadcast(message_data, channel_id)

    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, channel_id)
    except Exception as e:
        print(f"Unexpected WebSocket error: {e}")
        await websocket.close(code=1011)
