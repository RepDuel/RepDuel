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

### ⚡ Copy-Paste Bootstrap

> One-shot setup for macOS/Linux and Windows (PowerShell). Requires Docker Desktop (or a local PostgreSQL instance), Flutter, and Python to already be installed.

#### macOS / Linux

```bash
set -euo pipefail

# 1) Python + dependencies
python3 -m venv backend/.venv
source backend/.venv/bin/activate
pip install --upgrade pip
pip install -r backend/requirements.txt

# 2) Local Postgres (skip if you already have one running)
docker rm -f repduel-postgres 2>/dev/null || true
docker run --name repduel-postgres -p 5432:5432 \
  -e POSTGRES_USER=repduel \
  -e POSTGRES_PASSWORD=repduel \
  -e POSTGRES_DB=repduel \
  -d postgres:15-alpine

# 3) Backend env vars (edit the secrets before committing!)
cat <<'ENV' > backend/.env
APP_URL=http://localhost:5000
BASE_URL=http://127.0.0.1:8000
STATIC_PUBLIC_BASE=http://127.0.0.1:8000/static
DATABASE_URL=postgresql+asyncpg://repduel:repduel@localhost:5432/repduel
JWT_SECRET_KEY=change-this-access-secret
REFRESH_JWT_SECRET_KEY=change-this-refresh-secret
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30
REVENUECAT_WEBHOOK_AUTH_TOKEN=replace-with-test-token
STRIPE_SECRET_KEY=sk_test_replace_me
STRIPE_WEBHOOK_SECRET=whsec_replace_me
FRONTEND_ORIGINS=["http://localhost:3000","http://localhost:5000","http://localhost:5173"]
COOKIE_SAMESITE=lax
COOKIE_SECURE=false
ENV

# 4) Run migrations
pushd backend >/dev/null
alembic upgrade head
popd >/dev/null

# 5) Frontend env vars
cat <<'ENV' > frontend/.env
BACKEND_URL=http://127.0.0.1:8000
MERCHANT_DISPLAY_NAME=RepDuel (Local)
PUBLIC_BASE_URL=http://localhost:5000
REVENUE_CAT_APPLE_KEY=replace-me
STRIPE_CANCEL_URL=http://localhost:5000/payment-cancel
STRIPE_PREMIUM_PLAN_ID=price_test
STRIPE_PUBLISHABLE_KEY=pk_test_replace_me
STRIPE_SUCCESS_URL=http://localhost:5000/payment-success
ENV

# Production: BACKEND_URL should point at https://api.repduel.com so the app talks to the
# dedicated API subdomain. Make sure the backend uses COOKIE_DOMAIN=.repduel.com,
# COOKIE_SAMESITE=None, and COOKIE_SECURE=true when deploying cross-origin. Set
# FRONTEND_ORIGINS to every web origin that will load the app (e.g. Render static hosting,
# marketing preview domains) so CORS stays aligned with your deploy target.

# 6) Sync Flutter deps
pushd frontend >/dev/null
flutter pub get
popd >/dev/null

echo "Backend → source backend/.venv/bin/activate && cd backend && uvicorn app.main:app --reload"
echo "Frontend → cd frontend && flutter run -d chrome --web-port=5000"
```

#### Windows (PowerShell)

```powershell
$ErrorActionPreference = "Stop"

# 1) Python + dependencies
python -m venv backend\.venv
backend\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r backend\requirements.txt

# 2) Local Postgres (skip if you already have one running)
docker rm -f repduel-postgres 2>$null
docker run --name repduel-postgres -p 5432:5432 \`
  -e POSTGRES_USER=repduel \`
  -e POSTGRES_PASSWORD=repduel \`
  -e POSTGRES_DB=repduel \`
  -d postgres:15-alpine

# 3) Backend env vars (edit the secrets before committing!)
@'
APP_URL=http://localhost:5000
BASE_URL=http://127.0.0.1:8000
STATIC_PUBLIC_BASE=http://127.0.0.1:8000/static
DATABASE_URL=postgresql+asyncpg://repduel:repduel@localhost:5432/repduel
JWT_SECRET_KEY=change-this-access-secret
REFRESH_JWT_SECRET_KEY=change-this-refresh-secret
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30
REVENUECAT_WEBHOOK_AUTH_TOKEN=replace-with-test-token
STRIPE_SECRET_KEY=sk_test_replace_me
STRIPE_WEBHOOK_SECRET=whsec_replace_me
FRONTEND_ORIGINS=["http://localhost:3000","http://localhost:5000","http://localhost:5173"]
COOKIE_SAMESITE=lax
COOKIE_SECURE=false
'@ | Set-Content -Encoding UTF8 backend\.env

# 4) Run migrations
Push-Location backend
alembic upgrade head
Pop-Location

# 5) Frontend env vars
@'
BACKEND_URL=http://127.0.0.1:8000
MERCHANT_DISPLAY_NAME=RepDuel (Local)
PUBLIC_BASE_URL=http://localhost:5000
REVENUE_CAT_APPLE_KEY=replace-me
STRIPE_CANCEL_URL=http://localhost:5000/payment-cancel
STRIPE_PREMIUM_PLAN_ID=price_test
STRIPE_PUBLISHABLE_KEY=pk_test_replace_me
STRIPE_SUCCESS_URL=http://localhost:5000/payment-success
'@ | Set-Content -Encoding UTF8 frontend\.env

# Production: BACKEND_URL should point at https://api.repduel.com and the backend cookies
# must be configured for cross-site usage (COOKIE_DOMAIN=.repduel.com, COOKIE_SAMESITE=None,
# COOKIE_SECURE=true).

# 6) Sync Flutter deps
Push-Location frontend
flutter pub get
Pop-Location

Write-Host "Backend → backend\\.venv\\Scripts\\Activate.ps1; Set-Location backend; uvicorn app.main:app --reload"
Write-Host "Frontend → Set-Location frontend; flutter run -d chrome --web-port=5000"
```

> 💡 If you prefer a different Postgres instance or already have secret keys, swap those values before running the script. The commands above overwrite any existing `.env` files.

---

## 🔧 Backend Setup (FastAPI)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate      # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
# Create or edit .env (see bootstrap block for template)
alembic upgrade head           # Run DB migrations
uvicorn app.main:app --reload
```

* Default backend URL: `http://localhost:8000`

---

## 📱 Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=5000
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
STATIC_PUBLIC_BASE=https://cdn.repduel.com

COOKIE_DOMAIN=.repduel.com
COOKIE_SAMESITE=None
COOKIE_SECURE=true

REVENUECAT_WEBHOOK_AUTH_TOKEN=your_token
STRIPE_SECRET_KEY=your_stripe_key
STRIPE_WEBHOOK_SECRET=your_webhook_secret
```

### Static assets & CDN policy

* **Single origin for uploads** – all user generated files live behind the CDN URL defined by `STATIC_PUBLIC_BASE` (e.g. `https://cdn.repduel.com`).
* **Database stores keys only** – the backend persists storage keys like `avatars/abc123.jpg`; responses automatically expand them to absolute URLs using `STATIC_PUBLIC_BASE`.
* **Direct-to-storage ready** – clients can upload to S3/GCS (or MinIO in dev) using presigned URLs and only send the resulting object key back to the API.
* **Local dev parity** – set `STATIC_PUBLIC_BASE=http://127.0.0.1:8000/static` to keep behaviour consistent without serving assets off random localhost ports.

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
