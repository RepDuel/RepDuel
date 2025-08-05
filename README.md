
---

# 🥇 RepDuel

**RepDuel** is a gamified fitness platform for tracking workouts, competing on leaderboards, and analyzing performance — all in real time. Built with a cross-platform Flutter frontend and a high-performance FastAPI backend, RepDuel is designed for lifters, athletes, and fitness enthusiasts who want accountability, progression, and community.

---

## 🧩 Tech Stack

| Layer      | Technology                    |
| ---------- | ----------------------------- |
| Frontend   | Flutter + Riverpod            |
| Backend    | FastAPI + PostgreSQL          |
| Real-time  | WebSockets                    |
| Auth       | OAuth2 + JWT                  |
| DevOps     | Docker + GitHub Actions       |
| Storage    | Cloud image hosting (e.g. S3) |
| State Mgmt | Riverpod                      |

---

## 📦 Monorepo Structure

```
repduel/
├── frontend/              # Flutter App (iOS, Android, Web)
│   ├── lib/
│   │   ├── core/          # Providers, API services, models
│   │   ├── features/      # Auth, chat, profile, routines, leaderboard
│   │   ├── widgets/       # Shared UI widgets
│   │   ├── router/        # GoRouter navigation
│   │   └── main.dart
│   ├── assets/            # Images (e.g. ranks)
│   └── pubspec.yaml
│
├── backend/               # FastAPI Backend
│   ├── app/
│   │   ├── api/v1/        # Routes (auth, chat, routines, user, etc)
│   │   ├── services/      # Business logic
│   │   ├── models/        # SQLAlchemy models
│   │   ├── schemas/       # Pydantic v2 schemas
│   │   └── main.py        # App entrypoint
│   ├── alembic/           # Database migrations
│   ├── Dockerfile
│   └── requirements.txt
├── docker-compose.yml
└── README.md              # You are here
```

---

## 🚀 Key Features

### 💪 Fitness & Workout Tracking

* Custom routines and ranked lifts (Squat, Bench, Deadlift)
* Total volume, sets/reps tracking
* Auto-generated workout summaries and titles

### 📈 Energy & Progression System

* Personalized **energy scores** based on user weight and lift strength
* Interpolated energy formula to encourage improvement
* Ranks: Iron → Bronze → Silver → ... → Celestial

### 🧠 Analytics & Leaderboards

* Energy-based global leaderboard
* Lift-specific leaderboards
* Progress bars, energy graphs, performance trendlines

### 💬 Real-time Chat (Discord-style)

* WebSocket-based chat per room/lift
* Fully enriched messages with avatars, ranks, timestamps

### 👤 User Accounts

* JWT Auth (OAuth2 PasswordBearer)
* Profile pics, weight, gender, units (kg/lbs)
* Data persisted in PostgreSQL

---

## 🛠️ Getting Started

### Prerequisites

* Git
* Docker & Docker Compose
* Python 3.10+
* Flutter 3.x+
* PostgreSQL locally or via cloud (e.g. Render)

---

## 🔧 Backend Setup (FastAPI)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate      # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env           # Update DB creds, SECRET_KEY
alembic upgrade head           # Run DB migrations
uvicorn app.main:app --reload
```

* Default backend URL: `http://localhost:8000`

---

## 📱 Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get
flutter run                    # Select browser/device
```

* Web: `http://localhost:5000`
* Mobile: iOS/Android emulator or physical device

---

## 🐳 Docker Setup

To spin up the full stack with Docker:

```bash
docker-compose up --build
```

This runs:

* FastAPI on `localhost:8000`
* PostgreSQL
* Redis (if used)
* Flutter web on `localhost:5000` (if configured in Dockerfile)

---

## 🧪 Testing

### Backend

```bash
cd backend
pytest
```

### Frontend

```bash
cd frontend
flutter test
```

---

## 🔐 Environment Variables

### Backend `.env`

```
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/repduel
SECRET_KEY=your_secret_key
```

---

## 🛣️ API Endpoints

* `POST /auth/register`
* `POST /auth/login`
* `GET /user/profile`
* `POST /routine/submit`
* `GET /leaderboard/energy`
* `GET /chat/messages`
* `WS /ws/chat/{scenario_id}`

---

## 📈 Rank System

Ranks are based on energy scores:

| Rank        | Energy Threshold |
| ----------- | ---------------- |
| Iron        | 100              |
| Bronze      | 200              |
| Silver      | 300              |
| Gold        | 400              |
| Platinum    | 500              |
| Diamond     | 600              |
| Jade        | 700              |
| Master      | 800              |
| Grandmaster | 900              |
| Nova        | 1000             |
| Astra       | 1100             |
| Celestial   | 1200             |

---

## ✅ Roadmap

* [x] Energy leaderboard + ranked lifts
* [x] Real-time WebSocket chat
* [x] Routine creation and submission
* [ ] Mobile push notifications
* [ ] Teams (Guilds) and challenges
* [ ] Performance badges and streaks

---

## 📄 License

This project is proprietary and not open-source. All rights reserved © 2025.

---
