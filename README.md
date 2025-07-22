# GymRank

GymRank is a fitness-focused, gamified ranking platform that tracks users' workout performances, facilitates competition through leaderboards, and provides comprehensive energy and performance analytics. It features interactive elements like real-time chat, user authentication, and customizable exercise routines.

## 📦 Project Structure

GymRank is built with a **frontend** in Flutter/Dart and a **backend** using Python (FastAPI) and PostgreSQL.

```
.
├── frontend (Flutter)
│   ├── lib
│   │   ├── core (API, models, providers, services)
│   │   ├── features (auth, chat, leaderboard, ranked exercises, routines, user profile)
│   │   ├── router (navigation logic)
│   │   ├── theme (UI theming)
│   │   └── widgets (reusable widgets)
│   ├── assets (icons, rank images)
│   ├── android
│   ├── ios
│   ├── web
│   ├── linux
│   ├── macos
│   └── windows
├── backend (FastAPI, PostgreSQL)
│   ├── auth (user authentication & authorization)
│   ├── guild (user groups or teams)
│   ├── leaderboard (performance metrics & ranking)
│   ├── messages (real-time chat via WebSockets)
│   ├── routines (exercise management)
│   ├── user profiles (personalized user data)
│   └── utils (shared utilities and helpers)
```

---

## 🚀 Features

### ✅ Authentication & User Profiles

* **Secure Login & Registration** (JWT-based auth)
* **Profile Customization** (avatar uploads, preferences)

### 📊 Exercise Tracking & Analytics

* **Ranked Lifts**: Squat, Bench Press, Deadlift
* **Customizable Routines** with tracking and summary results
* **Energy Metrics**: computed through interpolated energy formulas based on lift standards, user scores, and multipliers.

### 🎯 Leaderboards

* **Energy Leaderboard**: rank users by computed "energy" metric.
* **Lift-specific Leaderboards**: compare performance across individual lifts.

### 💬 Real-time Chat

* **WebSocket integration** for instant messaging and community interaction.

---

## ⚙️ Tech Stack

* **Frontend**: Flutter, Dart, Riverpod
* **Backend**: FastAPI, Python, Alembic, PostgreSQL
* **Real-time communication**: WebSockets
* **Authentication**: JWT
* **Deployment**: Containerized environments (Docker compatible)

---

## 📐 Energy and Ranking Logic

GymRank calculates user performance based on a personalized "multiplier" derived from user-specific metrics (e.g., body weight):

```dart
final adjustedScore = userScore * userMultiplier;
```

### **Progress Bar Calculation**

```dart
progress = (adjustedScore - currentThreshold) / (nextThreshold - currentThreshold);
```

* Thresholds are standard benchmarks retrieved from the backend and adjusted based on the user's multiplier.

### **Interpolated Energy Calculation**

Energy values are interpolated between lift standards to produce meaningful, comparable metrics. Higher lifts and improvements result in higher energy and better ranks.

---

## 🎨 UI and Design

* Clean, minimalist style using dark mode colors.
* Animated progress bars and intuitive rank icons (SVG assets).
* Real-time UI updates reflecting user interactions and backend responses.

---

## 📁 File Structure Highlights (Frontend)

* **Auth**: `login_screen.dart`, `register_screen.dart`
* **Chat**: `chat_screen.dart`, `chat_bubble.dart`
* **Profile**: `profile_screen.dart`, `energy_graph.dart`
* **Ranked Exercises**: `ranking_table.dart`, `benchmarks_table.dart`
* **Routines**: `routine_play_screen.dart`, `exercise_list_screen.dart`

---

## 🛠️ Notable API endpoints (Backend)

* `/auth/login`
* `/auth/register`
* `/user/profile`
* `/leaderboard/energy`
* `/leaderboard/lifts`
* `/chat/messages`

---

## 📌 Current Development Status

You are currently refining UI components and backend integrations, specifically addressing issues related to score calculations, progress bar rendering, and accurate energy interpolations. Recent issues involved handling the user's multiplier properly in score computations.

---

## 📖 Planned Features & Enhancements

* Expanded lift scenarios and benchmarks.
* Enhanced customization for user routines.
* Additional detailed analytics dashboards.
* Push notifications for leaderboard and community updates.

---

![Build Status](https://img.shields.io/github/actions/workflow/status/YOUR_USERNAME/yavasuite/ci-cd.yml?branch=main)
![License](https://img.shields.io/badge/License-Proprietary-red.svg)

YavaSuite is a full-stack, real-time communication platform inspired by applications like Discord. It is architected for scalability and performance, featuring a high-concurrency Python/FastAPI backend and a responsive, cross-platform Flutter frontend.

This project is built to demonstrate modern software engineering principles, including containerization, automated CI/CD pipelines, and a clean, testable codebase.

## Core Features

-   **Real-time Messaging:** Instant message delivery using WebSockets.
-   **Guilds & Channels:** Organize communities into servers ("Guilds") and topic-based text channels.
-   **Secure Authentication:** JWT-based authentication with OAuth2 password flow.
-   **User Presence:** Real-time updates for user online status and typing indicators.
-   **Role-Based Access Control (RBAC):** Granular permissions for guild administrators and members.
-   **Cloud Media Uploads:** Secure and direct file uploads to a cloud storage provider.

## Tech Stack & Architecture

This project uses a modern, decoupled architecture to ensure scalability and maintainability.

| Backend                               | Frontend                             | Infrastructure & DevOps                |
| ------------------------------------- | ------------------------------------ | -------------------------------------- |
| **Python 3.10+**                      | **Flutter 3.x**                      | **Docker & Docker Compose**            |
| **FastAPI** (for REST & WebSockets)   | **Dart 2.18+**                       | **PostgreSQL** (Relational Database)   |
| **SQLAlchemy 2.x** (ORM)              | **Riverpod** (State Management)      | **Redis** (Caching & Pub/Sub)          |
| **Pydantic V2** (Data Validation)     | **GoRouter** (Navigation)            | **Nginx** (Reverse Proxy)              |
| **Alembic** (Database Migrations)     | **Dio** (HTTP Client)                | **GitHub Actions** (CI/CD)             |
| **Pytest** (Testing)                  | `web_socket_channel`                 | **AWS S3 / MinIO** (Object Storage)    |

### High-Level Architecture Diagram

```text
+----------------+      +---------------------+      +------------------------+
| Client         |      | Nginx Reverse Proxy |      | FastAPI App Instances  |
| (Flutter App   |----->| (SSL Termination,   |----->| (Running in Docker)    |
| iOS, Android,  |      |  Rate Limiting)     |      |                        |
| Web)           |      +---------------------+      +-----------+------------+
+----------------+                                                |
                                                                  | (SQLAlchemy ORM)
       +------------------+     +---------------------+           |
       | Redis            |<--->| WebSocket Manager & |<----------+
       | (Caching &       |     | Pub/Sub Listener    |
       |  Pub/Sub Broker) |     +---------------------+
       +------------------+

                               +----------------------+
                               | PostgreSQL Database  |
                               +----------------------+
```

## Project Structure

The project is a monorepo containing the `backend` and `frontend` applications.

```
yavasuite/
├── .github/workflows/ci-cd.yml # CI/CD Pipeline
├── backend/                    # FastAPI Application
│   ├── app/
│   │   ├── api/                # API endpoint definitions
│   │   ├── core/               # Configuration, security
│   │   ├── db/                 # Database session, migrations (alembic)
│   │   ├── models/             # SQLAlchemy ORM models
│   │   ├── schemas/            # Pydantic data schemas
│   │   ├── services/           # Business logic
│   │   └── main.py             # FastAPI app entrypoint
│   ├── tests/                  # Pytest integration and unit tests
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/                   # Flutter Application
│   ├── lib/
│   │   ├── core/               # Shared services, models, providers
│   │   ├── features/           # App features (auth, chat, home) organized by screen
│   │   ├── router/             # Navigation logic (GoRouter)
│   │   ├── theme/              # App theme data
│   │   └── main.dart           # Flutter app entrypoint
│   ├── test/                   # Flutter widget tests
│   └── pubspec.yaml
├── docker-compose.yml          # Local development environment orchestration
├── LICENSE.md                  # The project's commercial license
└── README.md
```

## Getting Started

Follow these instructions to get the project running on your local machine.

### Prerequisites

-   Git
-   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.x)
-   [Docker](https://www.docker.com/products/docker-desktop/) & Docker Compose
-   Python 3.10+ & `venv`

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/yavasuite.git
cd yavasuite
```

### 2. Backend Setup

First, set up the Python environment and database.

```bash
# Navigate to the backend directory
cd backend

# Create and activate a Python virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows, use: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create your local environment file from the example
cp .env.example .env
```
**Important:** Open the new `backend/.env` file and fill in the required variables, like `POSTGRES_PASSWORD` and `SECRET_KEY`.

### 3. Frontend Setup

Now, install the Flutter package dependencies.

```bash
# Navigate to the frontend directory from the root
cd frontend

# Get Flutter packages
flutter pub get

# Return to the root directory
cd ..
```

## Running the Application

The entire backend stack (API, database, Redis) is managed by Docker Compose.

1.  **Start the backend services:** From the root `yavasuite/` directory, run:
    ```bash
    docker-compose up --build
    ```
    The FastAPI server will be available at `http://localhost:8000`.

2.  **Run the Flutter App:** In a separate terminal, navigate to the `frontend/` directory and run:
    ```bash
    # From yavasuite/frontend/
    flutter run
    ```
    Select a target device (iOS Simulator, Android Emulator, or a browser) to launch the app.

## Running Tests

-   **Backend Tests:**
    ```bash
    # From yavasuite/backend/ with virtual environment activated
    pytest
    ```

-   **Frontend Tests:**
    ```bash
    # From yavasuite/frontend/
    flutter test
    ```

## License

This project is licensed under a proprietary license. See the `LICENSE.md` file for details.
