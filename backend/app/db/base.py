# backend/app/db/base.py

# Import all of the models, so that Base has them before being
# imported by Alembic
from app.db.base_class import Base
from app.models.energy_history import EnergyHistory
from app.models.guild import Guild
from app.models.leaderboard import LeaderboardEntry
from app.models.routine import Routine
from app.models.routine_scenario import RoutineScenario
from app.models.routine_submission import (RoutineScenarioSubmission,
                                           RoutineSubmission)
from app.models.scenario import Scenario
from app.models.score import Score
from app.models.user import User
from app.models.hidden_routine import HiddenRoutine
from app.models.bodyweight_calibration import BodyweightCalibration
from app.models.xp_event import XPEvent
from app.models.user_xp import UserXP
from app.models.social import SocialEdge
