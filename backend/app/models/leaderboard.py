from sqlalchemy import Column, Integer, ForeignKey, Float
from app.db.base_class import Base

class LeaderboardEntry(Base):
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    scenario_id = Column(Integer, ForeignKey("scenario.id"))
    weight_lifted = Column(Float)
