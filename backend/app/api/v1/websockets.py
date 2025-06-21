from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from uuid import UUID
from typing import Dict, List

from app.core.auth import get_current_user_ws
from app.services.message_service import create_message
from app.schemas.message import MessageCreate
from app.db.session import async_session

router = APIRouter()
active_connections: Dict[UUID, List[WebSocket]] = {}

@router.websocket("/ws/{channel_id}")
async def websocket_chat(
    websocket: WebSocket,
    channel_id: UUID,
    token: str = Query(...)
):
    user = await get_current_user_ws(websocket, token)
    await websocket.accept()

    if channel_id not in active_connections:
        active_connections[channel_id] = []
    active_connections[channel_id].append(websocket)

    try:
        while True:
            text = await websocket.receive_text()

            async with async_session() as db:
                await create_message(
                    db=db,
                    message_in=MessageCreate(content=text, channel_id=channel_id),
                    author_id=user.id,
                )

            for connection in active_connections[channel_id]:
                if connection.client_state.name == "CONNECTED":
                    await connection.send_text(f"{user.username}: {text}")

    except WebSocketDisconnect:
        active_connections[channel_id].remove(websocket)
        if not active_connections[channel_id]:
            del active_connections[channel_id]
