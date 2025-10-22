# 🥇 RepDuel

**RepDuel** is a gamified fitness platform for tracking workouts, competing on leaderboards, and analyzing performance. Built with a **cross-platform Flutter frontend** and a **high-performance FastAPI backend**, RepDuel gives lifters and athletes the accountability, progression, and community needed to level up together.

---

## 🧭 Platform Overview

| Area            | Details                                                                 |
| --------------- | ------------------------------------------------------------------------ |
| Backend         | FastAPI (Python 3.12) exposed as `app.main:app`                          |
| Frontend        | Flutter Web (Riverpod + GoRouter) served via Caddy                       |
| Auth            | OAuth2 password bearer with JWT access + rotating refresh tokens         |
| Payments        | RevenueCat (mobile) + Stripe Checkout & Customer Portal (web)            |
| Primary Domain  | `www.repduel.com`                                                        |
| API Domain      | `https://api.repduel.com` (reverse proxied to `127.0.0.1:9999`)          |
| Deployment Host | Hetzner VPS (`178.156.201.92`, Ubuntu 24.04 LTS, managed by `deploy` user)|

---

## 🧩 Monorepo Structure

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

## ⚙️ Production Operations

RepDuel production traffic is routed through **Caddy**, which terminates TLS, enforces security headers (CSP, HSTS, X-Frame-Options), and proxies API requests to the FastAPI process. The backend runs under **systemd** and loads secrets through **Doppler**.

### Server Environment

* **Provider:** Hetzner VPS (`178.156.201.92`)
* **OS:** Ubuntu 24.04 LTS
* **Python:** System 3.12 (virtualenv at `/home/deploy/repduel/backend/.venv`)
* **Firewall:** UFW open for TCP `9999`
* **Process Manager:** `systemd` (`repduel-backend.service`)

### Filesystem Layout

```
/home/deploy/
├── repduel/
│   ├── backend/              # FastAPI application
│   ├── deploy/               # Caddyfile + deploy scripts
│   └── tools/redeploy.sh     # Zero-guess redeploy script
├── backups/
├── render_backup.dump
└── …
```

### Caddy

* Serves the Flutter web app on `repduel.com` / `www.repduel.com`
* Proxies API traffic on `api.repduel.com` → `127.0.0.1:9999`
* Automatically manages TLS, CORS, CSP, and preflight `OPTIONS`
* Config lives at `/etc/caddy/Caddyfile` (symlink to `deploy/Caddyfile`)

Validation & reload commands:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy reload --config /etc/caddy/Caddyfile
```

### Systemd Service (`/etc/systemd/system/repduel-backend.service`)

```ini
[Unit]
Description=RepDuel FastAPI (prod)
After=network-online.target

[Service]
User=deploy
WorkingDirectory=/home/deploy/repduel/backend
Environment=PORT=9999
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/env bash -lc 'exec doppler run --project repduel --config prd_backend -- /home/deploy/repduel/backend/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 2 --proxy-headers --forwarded-allow-ips="*"'
Restart=always
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
```

Useful commands:

```bash
sudo systemctl daemon-reload
sudo systemctl restart repduel-backend
sudo systemctl status repduel-backend
journalctl -u repduel-backend -n 50 --no-pager
```

### Zero-Guess Redeploy Script

The `/home/deploy/repduel/tools/redeploy.sh` script pulls the latest Git changes, restarts the backend service, and reloads Caddy in one step:

```bash
ssh deploy@178.156.201.92
/home/deploy/repduel/tools/redeploy.sh
```

### Verification Commands

```bash
# Backend health
curl -i http://127.0.0.1:9999/health

# CORS / preflight check
curl -i -X OPTIONS https://api.repduel.com/api/v1/users/login \
  -H "Origin: https://www.repduel.com" \
  -H "Access-Control-Request-Method: POST"

# Login flow (expected 401 with invalid credentials)
curl -i -X POST https://api.repduel.com/api/v1/users/login \
  -H "Origin: https://www.repduel.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'username=test@example.com&password=wrong'
```

### Marketing landing page (repduel.com)

- The `/` route now renders a citadel.com-inspired marketing experience implemented in `frontend/lib/features/landing/screens/landing_page_screen.dart`.
- Preview locally with `cd frontend && flutter run -d chrome --web-renderer canvaskit` (requires the Flutter SDK).
- Deployment is handled by the existing **Deploy Web** workflow; see `docs/landing-page.md` for the full playbook and fallback server steps.

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
* [Doppler CLI](https://docs.doppler.com/docs/install-cli) (logged in or configured with a service token)

### ▶️ First-time setup for `make backend` / `make frontend`

After cloning the repository, run the following commands once to prepare the
tooling that the `make` targets expect:

```bash
# Backend virtualenv + dependencies
python3 -m venv backend/.venv
source backend/.venv/bin/activate
pip install --upgrade pip
pip install -r backend/requirements.txt
pip install "psycopg2-binary==2.9.9"

# Authenticate Doppler (choose one):
doppler login                                   # interactive device login, or
# export DOPPLER_TOKEN=dp.st.xxxxxx             # service token with dev access

# (Optional) Pin defaults so you can omit --project/--config later
doppler setup --project repduel --config dev_backend || true
doppler setup --project repduel --config dev_frontend || true

# Run migrations with Doppler-provided env vars (from repo root)
doppler run --project repduel --config dev_backend -- \
  bash -lc 'cd backend && alembic upgrade head'
deactivate

# Frontend dependencies
( cd frontend && flutter pub get )
```

With the prerequisites in place you can launch both services from separate
terminals:

```bash
make backend   # FastAPI dev server (requires Doppler secrets + reachable DB)
make frontend  # Flutter web app on http://localhost:5000
```

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

### 🛰️ Remote Postgres access for local development

If your Postgres instance lives on a remote host (for example a Hetzner VM at
`178.156.201.92`), set the Doppler `dev_backend` secret `DATABASE_URL` to the
public connection string (e.g.
`postgresql+asyncpg://appuser:supersecret@178.156.201.92:5432/app1db`). The
startup script derives a tunnel-friendly DSN automatically and exposes it as
`DATABASE_URL_INTERNAL`, mirroring Render's environment variables. Tunnelling is
**on by default** and the script assumes your macOS/Linux username on the
Hetzner host (`${USER}@178.156.201.92`) if you haven't set `SSH_TARGET`, so in
many cases you can just run `make backend`:

```bash
make backend
```

The script binds to `127.0.0.1:5433` locally to avoid clashing with an existing
Postgres install. If you prefer a different bind, adjust
`LOCAL_DB_HOST`/`LOCAL_DB_PORT`. The generated `DATABASE_URL_INTERNAL` will
always reflect the chosen bind while `DATABASE_URL` continues to point at the
remote host, matching Render's `DATABASE_URL`/`DATABASE_URL_INTERNAL` pairing.

Optional overrides:

* `LOCAL_DB_HOST` / `LOCAL_DB_PORT` – customise the local bind interface/port
  (defaults to `127.0.0.1:5433`).
* `REMOTE_DB_HOST` / `REMOTE_DB_PORT` – change the remote endpoint if your
  database is not bound to `127.0.0.1:5432` on the SSH host.
* `SSH_IDENTITY_FILE` – path to a private key if you need to force a
  non-default identity.
* `SSH_EXTRA_OPTS` – any additional `ssh(1)` CLI flags (for example
  `"-J bastion.example.com"`).

Disable the tunnel temporarily via `USE_SSH_TUNNEL=0 make backend`. If you need
to force a different SSH user or host, export `SSH_TARGET` explicitly before
running the script. The tunnel stays alive while Uvicorn is running and cleans
itself up on exit, so your local `DATABASE_URL` can remain unchanged.

### 🌐 Production deployment checklist

When deploying to Hetzner (or any new host) make sure the infrastructure pieces below are in place so authentication keeps working:

1. **SPA routing fallback** – static hosts must rewrite unknown paths such as `/login` to `/index.html`. The provided `deploy/Caddyfile` already does this via `try_files`.
2. **Content-Security-Policy** – allow Stripe and RevenueCat domains in `script-src`, `style-src`, `connect-src`, and `frame-src`. Stripe Elements now pulls helper assets from `https://m.stripe.com`, `https://m.stripe.network`, and `https://hooks.stripe.com` and also injects `blob:` backed workers/styles, so make sure those sources remain present. The sample Caddyfile contains a hardened baseline you can extend if new integrations are added.
3. **CORS + cookies** – set `FRONTEND_ORIGINS` (backend) to include `https://www.repduel.com`, enable credentials, and send cookies with `Domain=.repduel.com; Secure; SameSite=None; Path=/` so browsers attach them cross-origin.
4. **Stable auth secrets** – keep `JWT_SECRET_KEY` and `REFRESH_JWT_SECRET_KEY` consistent across redeploys to avoid invalidating all sessions.
5. **Service worker cache busting** – when CSP or assets change, unregister the old service worker in DevTools (Application → Service Workers) and trigger a hard refresh so the new policy takes effect.

The `deploy/Caddyfile` can be copied to `/etc/caddy/Caddyfile` on the host (adjusting the `root` path if necessary) and run with `caddy run --config /etc/caddy/Caddyfile`.

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
* **iOS release builds:** make sure the backend URLs are passed via `--dart-define` so the app doesn't fall back to `http://localhost`. Example:

  ```bash
  flutter run --release -d <device-id> \
    --dart-define=BACKEND_URL=https://api.repduel.com \
    --dart-define=PUBLIC_BASE_URL=https://api.repduel.com/static
  ```

  The Flutter bootstrap prints the resolved values at launch (look for `Env: --dart-define ...` in the logs). The default iOS `Info.plist` already whitelists HTTPS traffic to `api.repduel.com` via App Transport Security.

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
# Optional: prefer the CDN URL when constructing public asset links (defaults to API static origin)
STATIC_PREFER_CDN=false
# Optional: extend the connection bootstrap timeout (seconds) if you're on a slow network
REPDUEL_DB_BOOTSTRAP_TIMEOUT=10

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
