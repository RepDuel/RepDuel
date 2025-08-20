# backend/app/api/v1/websockets.py

import json
from uuid import UUID

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.core.auth import get_current_user_ws
from app.db.session import async_session
from app.schemas.message import MessageCreate, MessageRead
from app.services.message_service import create_message
from app.services.websocket_manager import WebSocketManager

router = APIRouter()
ws_manager = WebSocketManager()


@router.websocket("/ws/{channel_id}")
async def websocket_chat(
    websocket: WebSocket, channel_id: UUID, token: str = Query(...)
):
    user = await get_current_user_ws(websocket, token)
    if not user:
        await websocket.close(code=1008)
        return

    await ws_manager.connect(websocket, channel_id)

    try:
        while True:
            text = await websocket.receive_text()

            try:
                data = json.loads(text)
                content = data.get("content")
                if not content:
                    continue
            except json.JSONDecodeError:
                content = text  # Fallback for plain text messages

            async with async_session() as db:
                message_in = MessageCreate(content=content, channel_id=channel_id)
                message = await create_message(
                    db=db,
                    message_in=message_in,
                    author_id=user.id,
                )

                message_dict = MessageRead.model_validate(message).model_dump(
                    mode="json"
                )

            # Broadcast the dictionary. The manager will handle the final encoding.
            await ws_manager.broadcast(message_dict, channel_id)

    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, channel_id)
    except Exception as e:
        print(f"Unexpected WebSocket error: {e}")
        await websocket.close(code=1011)
