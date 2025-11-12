# RepDuel Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL INTERNET                           │
└────────────────────────────────┬──────────────────────────────────┘
                                 │
                    HTTPS:443 api.repduel.com
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      HETZNER VPS (178.156.201.92)                   │
│                          Ubuntu 24.04 LTS                            │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    CADDY REVERSE PROXY                        │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ Domain: api.repduel.com                                  │ │ │
│  │  │ - TLS Termination (Let's Encrypt)                        │ │ │
│  │  │ - Compress: gzip, zstd                                   │ │ │
│  │  │ - Routes /static/* with 1-year cache                     │ │ │
│  │  │ - Reverse proxy to 127.0.0.1:9999                        │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              │                                       │
│                  HTTP 127.0.0.1:9999                                │
│                              │                                       │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              FASTAPI BACKEND (app.main:app)                   │ │
│  │            (Runs as 'deploy' user via systemd)                │ │
│  │                                                                │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ Uvicorn Server                                           │ │ │
│  │  │ - 2 workers (parallel request handling)                  │ │ │
│  │  │ - Port: 9999 (localhost only)                            │ │ │
│  │  │ - Proxy headers enabled                                  │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ FastAPI Application                                      │ │ │
│  │  │ - CORS middleware (origin validation)                    │ │ │
│  │  │ - JWT authentication (access + refresh tokens)           │ │ │
│  │  │ - Static file serving (/static, /assets, etc)            │ │ │
│  │  │ - Stripe webhook handling                                │ │ │
│  │  │ - RevenueCat webhook handling                            │ │ │
│  │  │ - Health check endpoints (/health, /health/db)           │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ Database Bootstrap (db_bootstrap.py)                     │ │ │
│  │  │ - On startup: init_env() called via lifespan             │ │ │
│  │  │ - Selects DSN: Internal > Local > Remote                 │ │ │
│  │  │ - Tests connectivity with 10s timeout                    │ │ │
│  │  │ - Sets DATABASE_URL for SQLAlchemy                       │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ SQLAlchemy Async ORM (db/session.py)                     │ │ │
│  │  │ - Driver: asyncpg                                        │ │ │
│  │  │ - Engine config:                                         │ │ │
│  │  │   • pool_pre_ping=True (validate connections)            │ │ │
│  │  │   • pool_recycle=3600s (refresh hourly)                  │ │ │
│  │  │   • JIT disabled (consistent perf)                       │ │ │
│  │  │ - Async session manager                                  │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              │                                       │
│                   TCP 178.156.201.92:9991                           │
│                              │                                       │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │         POSTGRESQL DATABASE (Port 9991 - Custom)              │ │
│  │                                                                │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │ Database: app1db                                         │ │ │
│  │  │ User: appuser                                            │ │ │
│  │  │ Password: supersecret (via Doppler secrets)              │ │ │
│  │  │                                                          │ │ │
│  │  │ Tables:                                                  │ │ │
│  │  │ - users (auth, profiles)                                │ │ │
│  │  │ - routines (custom workout routines)                    │ │ │
│  │  │ - routine_submissions (workout logs)                    │ │ │
│  │  │ - scenarios (ranked lifts)                              │ │ │
│  │  │ - personal_best_events (PR tracking)                    │ │ │
│  │  │ - leaderboard (energy scores)                           │ │ │
│  │  │ - user_xp (experience points)                           │ │ │
│  │  │ - alembic_version (migration tracking)                  │ │ │
│  │  │ - (... 20+ more tables)                                 │ │ │
│  │  │                                                          │ │ │
│  │  │ Migrations: Alembic (async SQLAlchemy)                  │ │ │
│  │  │ Location: backend/alembic/versions/                     │ │ │
│  │  │ Recent: 27dcd007108a (next_change)                      │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              SYSTEMD SERVICE MANAGEMENT                        │ │
│  │  Service: repduel-backend.service                              │ │
│  │  User: deploy (non-root)                                       │ │
│  │  Startup: doppler run --project repduel --config prd_backend   │ │
│  │  ExecStart: uvicorn app.main:app --port 9999 --workers 2       │ │
│  │  Restart: always (3s delay)                                    │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              SECRETS MANAGEMENT (DOPPLER)                      │ │
│  │  Project: repduel                                              │ │
│  │  Config: prd_backend                                           │ │
│  │  Provides:                                                     │ │
│  │  - DATABASE_URL (PostgreSQL connection)                        │ │
│  │  - JWT_SECRET_KEY, REFRESH_JWT_SECRET_KEY                      │ │
│  │  - STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET                    │ │
│  │  - REVENUECAT_WEBHOOK_AUTH_TOKEN                               │ │
│  │  - APP_URL, BASE_URL                                           │ │
│  │  - STATIC_STORAGE_DIR                                          │ │
│  │  - (... other secrets)                                         │ │
│  │  Runtime injection: No secrets in code or env files            │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                                 │
                ┌────────────────┴────────────────┐
                │                                 │
                ▼                                 ▼
        ┌───────────────┐               ┌──────────────────┐
        │   Stripe API  │               │ RevenueCat Webhooks
        │ (Payments)    │               │ (Mobile payments)
        └───────────────┘               └──────────────────┘
```

## Data Flow: User Login

```
1. Client sends credentials → HTTPS → api.repduel.com:443
2. Caddy TLS termination → HTTP → 127.0.0.1:9999
3. FastAPI receives request → POST /api/v1/users/login
4. JWT validation service → Check credentials
5. SQLAlchemy query builder → async prepare
6. asyncpg connection pool → Get connection from pool
7. PostgreSQL executes → SELECT * FROM users WHERE email = ?
8. Result returned → asyncpg driver → SQLAlchemy ORM → FastAPI response
9. Response JSON + JWT tokens → HTTP → Caddy → HTTPS → Client
```

## Configuration Layers

```
┌──────────────────────────────────────────────────────┐
│ 1. DOPPLER SECRETS (Encrypted, never in code)        │
│    ├─ DATABASE_URL                                   │
│    ├─ JWT_SECRET_KEY                                 │
│    ├─ STRIPE_SECRET_KEY                              │
│    └─ ... (20+ secrets)                              │
└──────────────────────┬───────────────────────────────┘
                       │ doppler run --project repduel
                       │ --config prd_backend
                       │
┌──────────────────────▼───────────────────────────────┐
│ 2. PYDANTIC SETTINGS (backend/app/core/config.py)    │
│    ├─ DATABASE_URL: PostgresDsn (validated)          │
│    ├─ JWT_SECRET_KEY: str (required)                 │
│    ├─ STRIPE_SECRET_KEY: str (required)              │
│    ├─ APP_URL, BASE_URL, STATIC_STORAGE_DIR          │
│    └─ ... (30+ settings with defaults)               │
└──────────────────────┬───────────────────────────────┘
                       │ settings = Settings()
                       │
┌──────────────────────▼───────────────────────────────┐
│ 3. SQLALCHEMY ENGINE (backend/app/db/session.py)     │
│    ├─ create_async_engine(str(settings.DATABASE_URL))
│    ├─ pool_pre_ping=True                             │
│    ├─ pool_recycle=3600                              │
│    └─ connect_args={"server_settings": {"jit": "off"}}
└──────────────────────┬───────────────────────────────┘
                       │ async_session = sessionmaker(engine)
                       │
┌──────────────────────▼───────────────────────────────┐
│ 4. FASTAPI APP LIFESPAN (backend/app/main.py)        │
│    ├─ On startup: init_env() called                  │
│    ├─ pick_dsn() validates DB connectivity           │
│    ├─ Sets final DATABASE_URL                        │
│    └─ app is ready to serve requests                 │
└──────────────────────────────────────────────────────┘
```

## Deployment Process

```
┌─────────────────────────────┐
│  Code Push to GitHub main   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│  /tools/redeploy.sh (SSH deploy@178...)        │
│  1. git pull origin main                        │
│  2. pip install -r requirements.txt             │
│  3. sudo systemctl restart repduel-backend      │
│  4. sudo caddy reload --config /etc/caddy/...   │
│  5. curl http://localhost:9999/health           │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Systemd Service Starts       │
│ repduel-backend.service      │
└──────────────┬───────────────┘
               │
               ├─ doppler run --project repduel
               │              --config prd_backend
               │
               ├─ Load secrets (DATABASE_URL, etc)
               │
               ├─ Start uvicorn (2 workers)
               │
               ├─ init_env() validates DB connection
               │
               ▼
┌──────────────────────────────┐
│ Service Ready                │
│ ✓ Accepting requests on 9999 │
│ ✓ Database connected         │
│ ✓ Secrets loaded             │
└──────────────────────────────┘
```

## Database Connection Fallback Logic

```
┌─ init_env() called at app startup
│
├─ Read environment variables:
│  ├─ DATABASE_URL_INTERNAL or DATABASE_URL_LOCAL (preferred)
│  └─ DATABASE_URL or DATABASE_URL_REMOTE (fallback)
│
├─ Try local DSN first (if available)
│  ├─ await asyncpg.connect() with 10s timeout
│  ├─ If success → Use local DSN
│  └─ If fail → Log warning, try remote
│
├─ Try remote DSN (if available)
│  ├─ await asyncpg.connect() with 10s timeout
│  ├─ If success → Use remote DSN
│  └─ If fail → Go to strict mode check
│
├─ Strict mode (REPDUEL_STRICT_DB_BOOTSTRAP=1)?
│  ├─ Yes → Raise error, app startup fails
│  └─ No → Log warning, proceed with best guess
│
└─ Set os.environ["DATABASE_URL"] = chosen_dsn
   (Used by SQLAlchemy engine at request time)
```

## Security Architecture

```
┌─────────────────────────────────────────────────────┐
│ EXTERNAL ATTACK SURFACE                            │
│                                                      │
│  • HTTPS only (TLS 1.3 via Let's Encrypt)          │
│  • Origin validation (CORS middleware)              │
│  • JWT token validation (short-lived: 60 min)       │
│  • Refresh token rotation (30 days)                 │
│  • Secure cookies (SameSite=none, Secure)           │
│                                                      │
└──────────────────────┬────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ INTERNAL NETWORK SECURITY                           │
│                                                      │
│  • Backend on localhost:9999 (not externally bound) │
│  • Database on custom port 9991 (non-standard)      │
│  • UFW firewall configured                          │
│  • Non-root user (deploy) runs backend              │
│  • Process isolation via systemd                    │
│                                                      │
└──────────────────────┬────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ SECRETS MANAGEMENT                                  │
│                                                      │
│  • Doppler: Zero-trust secrets (encrypted at rest)  │
│  • Never in git (checked by pre-commit hooks)       │
│  • Never in environment files (.env ignored)        │
│  • Runtime injection via doppler run wrapper        │
│  • No secrets in process listings (masked)          │
│  • Rotatable without redeployment                   │
│                                                      │
└──────────────────────┬────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ DATABASE SECURITY                                   │
│                                                      │
│  • User: appuser (non-admin)                        │
│  • Password: Strong, stored in Doppler only         │
│  • Network: Accessible only from backend on same    │
│            server (no remote connections needed)    │
│  • Connection pool: Validated before each use       │
│  • SQL: Parameterized queries (no SQL injection)    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## Deployment Topology Summary

| Component | Type | Location | Port | Access |
|-----------|------|----------|------|--------|
| **Internet** | - | External | 443 | Public HTTPS |
| **Caddy** | Reverse Proxy | Hetzner VPS | 443 (ext), 9999 (int) | TLS termination |
| **FastAPI** | Web Framework | Hetzner VPS | 9999 | Localhost only |
| **PostgreSQL** | Database | Hetzner VPS | 9991 | Localhost only |
| **Systemd** | Process Manager | Hetzner VPS | - | Backend service |
| **Doppler** | Secrets Manager | Cloud | - | Runtime injection |

**Network Security:**
- All database traffic: localhost only (no remote access needed)
- All external traffic: HTTPS through Caddy
- Internal traffic: HTTP localhost (no encryption needed)
- Secrets: Never exposed in logs, env vars, or process listings

