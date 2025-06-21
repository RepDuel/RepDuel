import json
from typing import Dict, List
from fastapi import WebSocket
from uuid import UUID


class WebSocketManager:
    def __init__(self):
        # channel_id -> list of WebSockets
        self.active_connections: Dict[UUID, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, channel_id: UUID):
        await websocket.accept()
        if channel_id not in self.active_connections:
            self.active_connections[channel_id] = []
        self.active_connections[channel_id].append(websocket)
        print(f"WebSocket connected to channel {channel_id}. Total: {len(self.active_connections[channel_id])}")

    def disconnect(self, websocket: WebSocket, channel_id: UUID):
        connections = self.active_connections.get(channel_id, [])
        if websocket in connections:
            connections.remove(websocket)
            print(f"WebSocket disconnected from channel {channel_id}. Remaining: {len(connections)}")
        if not connections:
            self.active_connections.pop(channel_id, None)

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        await websocket.send_text(json.dumps(message))

    async def broadcast(self, message: dict, channel_id: UUID):
        connections = self.active_connections.get(channel_id, [])
        for connection in connections:
            await connection.send_text(json.dumps(message))
