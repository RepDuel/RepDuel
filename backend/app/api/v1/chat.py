import uuid
from datetime import datetime
from typing import List

from app.api.v1.deps import get_db
from app.core.auth import get_current_user_ws
from app.models.channel import Channel
from app.models.guild import Guild
from app.models.message import Message as MessageModel
from app.schemas.message import MessageRead
from fastapi import (APIRouter, Depends, HTTPException, WebSocket,
                     WebSocketDisconnect)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

router = APIRouter(tags=["chat"])
active_connections: List[WebSocket] = []


@router.websocket("/ws/chat/global")
async def websocket_global_chat(
    websocket: WebSocket,
    db: AsyncSession = Depends(get_db),
):
    await websocket.accept()

    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return

    user = await get_current_user_ws(websocket, token, db)
    if not user:
        return

    active_connections.append(websocket)

    # Ensure global guild
    result = await db.execute(select(Guild).where(Guild.name == "global"))
    global_guild = result.scalar_one_or_none()
    if not global_guild:
        global_guild = Guild(id=uuid.uuid4(), name="global", owner_id=user.id)
        db.add(global_guild)
        await db.commit()
        await db.refresh(global_guild)

    # Ensure global channel
    result = await db.execute(select(Channel).where(Channel.name == "global"))
    global_channel = result.scalar_one_or_none()
    if not global_channel:
        global_channel = Channel(
            id=uuid.uuid4(),
            name="global",
            guild_id=global_guild.id,
        )
        db.add(global_channel)
        await db.commit()
        await db.refresh(global_channel)

    try:
        while True:
            content = await websocket.receive_text()
            message = MessageModel(
                id=uuid.uuid4(),
                content=content,
                author_id=user.id,
                channel_id=global_channel.id,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            )
            db.add(message)
            await db.commit()

            for conn in active_connections:
                await conn.send_text(content)

    except WebSocketDisconnect:
        active_connections.remove(websocket)


@router.get("/history/global", response_model=List[MessageRead])
async def get_history(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.name == "global"))
    global_channel = result.scalar_one_or_none()
    if not global_channel:
        raise HTTPException(status_code=404, detail="No global channel")

    result = await db.execute(
        select(MessageModel)
        .where(MessageModel.channel_id == global_channel.id)
        .order_by(MessageModel.created_at.asc())
    )
    return result.scalars().all()
