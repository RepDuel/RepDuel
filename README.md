# 🥇 RepDuel

**RepDuel** is a gamified fitness platform for tracking workouts, competing on leaderboards, and analyzing performance. Built with a **cross-platform Flutter frontend** and a **high-performance FastAPI backend**, RepDuel is designed for lifters, athletes, and fitness enthusiasts who want accountability, progression, and community.

---

## 🧩 Tech Stack

| Layer      | Technology                           |
| ---------- | ------------------------------------ |
| Frontend   | Flutter + Riverpod + GoRouter        |
| Backend    | FastAPI + PostgreSQL + Alembic       |
| Auth       | JWT Access + Refresh Tokens (OAuth2) |
| Payments   | RevenueCat (iOS/Android) + Stripe    |
| State Mgmt | Riverpod                             |

---

## 📦 Monorepo Structure

```
repduel/
├── frontend/              # Flutter App (iOS, Android, Web)
│   ├── lib/
│   │   ├── core/          # Providers, API services, models
│   │   ├── features/      # Auth, profile, routines, leaderboard, premium
│   │   ├── widgets/       # Shared UI widgets
│   │   ├── router/        # GoRouter navigation
│   │   └── main.dart
│   ├── assets/            # Images (e.g. ranks, placeholders)
│   └── pubspec.yaml
│
├── backend/               # FastAPI Backend
│   ├── app/
│   │   ├── api/v1/        # Routes (users, payments, webhooks, etc)
│   │   ├── services/      # Business logic
│   │   ├── models/        # SQLAlchemy models
│   │   ├── schemas/       # Pydantic v2 schemas
│   │   ├── core/          # Security, config, auth helpers
│   │   └── main.py        # App entrypoint
│   ├── alembic/           # Database migrations
│   └── requirements.txt
└── README.md              # You are here
```

---

## 🚀 Key Features

### 💪 Fitness & Workout Tracking

* Custom routines and ranked lifts (Squat, Bench, Deadlift)
* Total volume, sets/reps tracking
* Auto-generated workout summaries and titles

### 📈 Energy & Rank System

* Personalized **Energy Scores** based on body weight + lift strength
* Ranks: Iron → Bronze → Silver → Gold → … → Celestial
* Energy graphs, streaks, and historical stats

### 🧠 Analytics & Leaderboards

* Global leaderboard ranked by Energy Score
* Lift-specific leaderboards
* Progression tracking with charts

### 👤 User Accounts & Auth

* OAuth2 + JWT (short-lived **access tokens** + rotating **refresh tokens**)
* No forced logouts — refresh tokens keep sessions alive
* Profile pics, weight, gender, and units (kg/lbs)

### 💳 Subscriptions

* **iOS/Android**: RevenueCat for In-App Purchases
* **Web**: Stripe Checkout + Customer Portal
* Gold/Platinum tiers managed by backend webhooks

---

## 🛠️ Getting Started

### Prerequisites

* Git
* Python 3.10+
* Flutter 3.x+
* PostgreSQL (local or hosted e.g. Render)

---

## 🔧 Backend Setup (FastAPI)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate      # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env           # Fill in DB creds, JWT secrets, Stripe keys
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

## 🔐 Environment Variables

### Backend `.env`

```env
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/repduel
JWT_SECRET_KEY=superlongrandomaccesssecret
JWT_REFRESH_SECRET_KEY=superlongrandomrefreshsecret
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

REVENUECAT_WEBHOOK_AUTH_TOKEN=your_token
STRIPE_SECRET_KEY=your_stripe_key
STRIPE_WEBHOOK_SECRET=your_webhook_secret
```

---

## 🛣️ API Endpoints

* `POST /users/` → Register
* `POST /users/login` → Login (sets refresh cookie + returns access token)
* `POST /users/refresh` → Rotate refresh token, mint new access token
* `POST /users/logout` → Clear refresh cookie, invalidate session
* `GET /users/me` → Get current user profile
* `PATCH /users/me` → Update profile
* `PATCH /users/me/avatar` → Upload avatar
* `DELETE /users/me` → Delete account
* `POST /payments/create-checkout-session` → Stripe checkout
* `POST /webhooks/revenuecat` → RevenueCat subscription events

---

## 📈 Rank System

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

## 🧪 Testing Subscriptions

### iOS/Android (RevenueCat Sandbox)

1. Log in with the **App Store Sandbox account** (iOS) or Play Store test account (Android).
2. In the app, go to **Settings → Upgrade to Gold**.
3. Complete the sandbox purchase flow (Apple/Google will show \$0.00).
4. After purchase, your account should be upgraded to **Gold** automatically.
5. To test **Restore Purchases**:

   * Delete the app, reinstall, and log in with the same RepDuel account.
   * Tap **Restore Purchases** in Settings — your Gold subscription should sync back.

### Web (Stripe Test Mode)

1. Log in with your RepDuel account.
2. Upgrade via **Manage Subscription** (Stripe Checkout opens).
3. Use a [Stripe test card](https://stripe.com/docs/testing) (e.g. `4242 4242 4242 4242`).
4. After completing checkout, your account will update to **Gold**.
5. Manage subscription anytime via **Stripe Customer Portal**.

---

## ✅ Roadmap

* [x] Energy leaderboard + ranked lifts
* [x] Routine creation and submission
* [x] Stripe + RevenueCat subscriptions
* [x] Refresh token–based auth (no forced logout)
* [ ] Teams (Guilds) and challenges
* [ ] Push notifications
* [ ] Performance badges and streaks

---

## 📄 License

This project is proprietary and not open-source.
All rights reserved © 2025.

---
