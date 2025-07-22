from sqlalchemy import Table, Column, String, ForeignKey
from app.db.base_class import Base

# Define the association table here so it can be reused
scenario_muscle_association = Table(
    "scenario_muscle_association",
    Base.metadata,
    Column("scenario_id", String, ForeignKey("scenarios.id"), primary_key=True),
    Column("muscle_id", String, ForeignKey("muscles.id"), primary_key=True),
)
