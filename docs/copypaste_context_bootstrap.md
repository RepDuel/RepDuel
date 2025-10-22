# RepDuel :: ChatGPT Context Bootstrap

Copy/paste this primer into a fresh ChatGPT session to orient the model before making changes to the repo.

---

## TL;DR
- **What:** RepDuel is a gamified strength-training platform with a FastAPI backend and a Flutter (web + mobile) frontend.
- **Why:** Tracks workouts, energy scores, ranks, leaderboards, and premium tiers to keep lifters engaged.
- **Where:** Backend served from `app.main:app`; Flutter web is bundled under `frontend/build/web` and optionally served by the backend.

---

## Monorepo Layout
```
repduel/
├── backend/            FastAPI app, async SQLAlchemy models, Alembic migrations
│   ├── app/
│   │   ├── api/v1/     Versioned API routers
│   │   ├── core/       Settings, auth, Celery, security helpers
│   │   ├── db/         Session helpers & async engine
│   │   ├── models/     SQLAlchemy ORM tables
│   │   ├── schemas/    Pydantic v2 request/response models
│   │   ├── services/   Business logic (auth, routines, leaderboards, etc.)
│   │   └── main.py     FastAPI entry point + CORS/static setup
│   ├── alembic/        Database migrations & env.py
│   ├── scripts/        Local dev helpers (tunneling, Doppler bootstrap)
│   └── tests/          Pytest suite (API + services)
├── frontend/           Flutter app (Riverpod, GoRouter, Stripe, RevenueCat)
│   ├── lib/core/       Env config, providers, API clients, models
│   ├── lib/features/   Auth, routines, ranked lifts, premium, profile, etc.
│   ├── lib/router/     `app_router.dart` GoRouter setup with tab shell navigation
│   ├── lib/widgets/    Shared UI components
│   └── pubspec.yaml
├── packages/           Flutter federated plugins (e.g., secure storage web shim)
├── deploy/             Production infra (Caddyfile, scripts)
└── README.md           Extended platform + operations guide
```

---

## Backend Quick Hits
- **Entry:** `backend/app/main.py` builds the FastAPI app, wires CORS, mounts static assets, and includes the v1 API router.
- **Env bootstrap:** `init_env()` (from `app/db_bootstrap.py`) seeds async SQLAlchemy configuration and Doppler-powered secrets during startup.
- **CORS:** Allowed origins combine env-configured URLs, localhost fallbacks, and production domains (`repduel.com`, `api.repduel.com`).
- **Static:** `/static` is backed by `STATIC_STORAGE_DIR`; Flutter web build folders (`assets`, `icons`, etc.) mount if present.
- **Persistence:** Async Postgres via `sqlalchemy[asyncpg]`; migrations handled with Alembic in `backend/alembic/`.
- **Auth:** OAuth2 password bearer with short-lived access JWTs + rotating refresh tokens; refresh cookies managed in `core/security` services.
- **Background tasks:** Celery app defined in `app/core/celery_app.py` (Redis broker expected via Doppler secrets).
- **Testing:** `pytest` under `backend/tests`; run with virtualenv activated and Doppler-provided env vars as needed.

---

## Frontend Quick Hits
- **Entry:** `frontend/lib/main.dart` initializes SharedPreferences, env vars (dotenv + `--dart-define`), and configures Stripe before running the Riverpod `ProviderScope`.
- **Routing:** `lib/router/app_router.dart` builds a `GoRouter` with a bottom-tab `StatefulShellRoute` (Ranked, Routines, Profile) and nested routes for leaderboards, workouts, onboarding, and premium flows.
- **State Management:** Riverpod providers for auth, navigation, routines, etc. Shared widgets live under `lib/widgets`.
- **Env config:** Flutter reads `.env` on device and compile-time `BACKEND_URL`/`PUBLIC_BASE_URL` defines on web.
- **Payments:** Integrates `flutter_stripe` for web checkout hand-off and RevenueCat for mobile subscriptions.
- **Theming:** Dark theme defined in `lib/theme/app_theme.dart`.

---

## Local Development (no Doppler required version)
1. **Python deps**
   ```bash
   python3 -m venv backend/.venv
   source backend/.venv/bin/activate
   pip install --upgrade pip
   pip install -r backend/requirements.txt
   ```
2. **Postgres (Docker)**
   ```bash
   docker rm -f repduel-postgres 2>/dev/null || true
   docker run --name repduel-postgres -p 5432:5432 \
     -e POSTGRES_USER=repduel \
     -e POSTGRES_PASSWORD=repduel \
     -e POSTGRES_DB=repduel \
     -d postgres:15-alpine
   ```
3. **Backend env (`backend/.env`)** – set app URLs, JWT secrets, Stripe/RevenueCat placeholders, and `FRONTEND_ORIGINS`.
4. **Migrations**
   ```bash
   pushd backend
   alembic upgrade head
   popd
   ```
5. **Frontend env (`frontend/.env`)** – wire `BACKEND_URL`, Stripe keys, and success/cancel URLs.
6. **Flutter deps**
   ```bash
   ( cd frontend && flutter pub get )
   ```
7. **Run services**
   ```bash
   make backend   # uvicorn with hot reload (needs env vars)
   make frontend  # Flutter web dev server on http://localhost:5000
   ```

> The `README.md` also documents a Doppler-driven flow (`make backend` / `make frontend`) plus remote Postgres tunneling helpers if your DB lives on Hetzner.

---

## Testing & QA
- **Backend:** Activate the virtualenv, ensure env vars are loaded (via `.env` or Doppler), then run `pytest` inside `backend/`.
- **Frontend:** Use `flutter test` for widget/unit tests; `flutter analyze` / `dart analyze` for static analysis.
- **End-to-end:** Manual flows include login, routine playback, leaderboards, and premium purchase screens; API health at `/health`.

---

## Deployment & Operations
- **Prod host:** Hetzner VPS (`178.156.201.92`, Ubuntu 24.04) managed via `deploy` user.
- **Process manager:** `systemd` service `repduel-backend` runs uvicorn via Doppler with two workers.
- **Reverse proxy:** Caddy terminates TLS, serves Flutter web, and proxies API requests (`https://api.repduel.com → 127.0.0.1:9999`). Config sits in `deploy/Caddyfile` and symlinks to `/etc/caddy/Caddyfile`.
- **Zero-guess redeploy:** SSH in and run `/home/deploy/repduel/tools/redeploy.sh` to pull latest Git, restart backend, and reload Caddy.
- **Troubleshooting:**
  ```bash
  sudo systemctl restart repduel-backend
  journalctl -u repduel-backend -n 50 --no-pager
  sudo caddy reload --config /etc/caddy/Caddyfile
  curl -i http://127.0.0.1:9999/health
  ```

---

## Feature Highlights
- Ranked lifts (squat/bench/deadlift) with global & lift-specific leaderboards.
- Energy score system that tracks streaks and historical stats.
- Custom and templated routines, free workouts, summaries, and result sharing.
- Auth flows with rotating refresh tokens to avoid forced logouts.
- Premium tiers via Stripe (web) and RevenueCat (mobile) with webhook handling.

---

## Handy References
- Root README: platform overview, setup scripts, production ops.
- `backend/start_backend.sh` & `.ps1`: dev convenience wrappers around Doppler + uvicorn.
- `deploy/`: production infra-as-code (Caddy, backup notes, service templates).
- `packages/flutter_secure_storage_web_stub`: shim package for browser secure storage behavior.

