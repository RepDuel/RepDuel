from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
import uuid

from app.db.session import get_db
from app.models.message import Message as MessageModel
from app.schemas.message import MessageRead  # if using Pydantic schemas

router = APIRouter()

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


@router.get("/chat/history/global", response_model=List[MessageRead])
def get_global_chat_history(db: Session = Depends(get_db)):
    messages = (
        db.query(MessageModel)
        .filter(MessageModel.channel_id == "global")
        .order_by(MessageModel.created_at.asc())
        .all()
    )
    return messages
