# backend/app/db/base.py

from app.db.base_class import Base

# Import all of the models
from app.models.user import User
from app.models.guild import Guild
from app.models.channel import Channel
from app.models.message import Message