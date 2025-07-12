from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
import uuid

from app.api.v1.deps import get_db
from app.models.message import Message as MessageModel
from app.schemas.message import MessageRead
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException
from app.models.channel import Channel



router = APIRouter(prefix="/chat", tags=["chat"])

active_connections: List[WebSocket] = []


@router.websocket("/ws/chat/global")
async def websocket_global_chat(websocket: WebSocket, db: Session = Depends(get_db)):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            content = await websocket.receive_text()

            # Save message to the database
            message = MessageModel(
                id=str(uuid.uuid4()),
                content=content,
                author_id="anon",  # Replace with actual user ID from JWT if available
                channel_id="global",
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            )
            db.add(message)
            db.commit()

            # Broadcast to all clients
            for conn in active_connections:
                if conn != websocket:
                    await conn.send_text(content)
    except WebSocketDisconnect:
        active_connections.remove(websocket)


@router.get("/history/global", response_model=List[MessageRead])
async def get_global_chat_history(db: AsyncSession = Depends(get_db)):
    # Step 1: Get the UUID of the "global" channel
    result = await db.execute(select(Channel).where(Channel.name == "global"))
    global_channel = result.scalar_one_or_none()

    if not global_channel:
        raise HTTPException(status_code=404, detail="Global channel not found")

    # Step 2: Fetch messages using that UUID
    result = await db.execute(
        select(MessageModel)
        .where(MessageModel.channel_id == global_channel.id)
        .order_by(MessageModel.created_at.asc())
    )
    messages = result.scalars().all()
    return messages