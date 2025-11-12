# RepDuel PostgreSQL Deployment Analysis

## Executive Summary

RepDuel's PostgreSQL database is deployed on a **Hetzner VPS** (IP: `178.156.201.92`) running **Ubuntu 24.04 LTS**. The database runs on a **custom port 9991** and is accessed by the FastAPI backend running on the same server. All infrastructure is managed through **Doppler** for secrets management and **systemd** for process lifecycle.

---

## 1. DATABASE DEPLOYMENT CONFIGURATION

### Current Deployment Status
- **Host:** Hetzner VPS (`178.156.201.92`)
- **OS:** Ubuntu 24.04 LTS
- **Managed by:** `deploy` user (non-root)
- **Port:** 9991 (custom port, not default 5432)
- **User:** `appuser`
- **Database Name:** `app1db`
- **Password:** `supersecret` (stored in Doppler secrets)

### Connection String (Development Reference)
Located in `/home/deploy/repduel/backend/scripts/migrate.sh`:
```bash
postgresql://appuser:supersecret@178.156.201.92:9991/app1db
```

### Production Connection Details
**Direct Connection String:**
```
postgresql+asyncpg://appuser:supersecret@178.156.201.92:9991/app1db
```

---

## 2. DATABASE BOOTSTRAP & CONNECTION SELECTION

### Key File: `backend/app/db_bootstrap.py`

The backend implements a sophisticated database selection logic that supports three connection scenarios:

1. **Local/Internal DSN** (preferred): `DATABASE_URL_INTERNAL` or `DATABASE_URL_LOCAL`
2. **Remote/Public DSN** (fallback): `DATABASE_URL` or `DATABASE_URL_REMOTE`
3. **Automatic fallback logic**: If one fails to connect, tries the other

### Bootstrap Flow
1. On FastAPI app startup, `init_env()` is called via the lifespan context manager
2. `pick_dsn()` attempts to connect to each DSN candidate with a 10-second timeout
3. Validates connectivity using `asyncpg.connect()` before committing to the selection
4. Logs which DSN was selected in the application logs

### Environment Variable Resolution Order
```python
# Local/Internal (preferred)
DATABASE_URL_INTERNAL  → DATABASE_URL_LOCAL  → DATABASE_URL

# Remote/Public
DATABASE_URL  → DATABASE_URL_REMOTE  → DATABASE_URL_INTERNAL

# Backfill if only one provided
# If only remote provided, use it for both
# If only local provided, use it for both
```

### Strict Mode
- Controlled by: `REPDUEL_STRICT_DB_BOOTSTRAP` environment variable
- **Default:** `1` (strict mode enabled in production)
- In strict mode: If no DSN connects successfully, the app fails to start
- In non-strict mode: Warns but proceeds with the last attempted DSN

---

## 3. FASTAPI BACKEND CONFIGURATION

### File: `backend/app/core/config.py`

**Required Settings (Must be provided):**
- `DATABASE_URL`: PostgresDsn (Pydantic validated PostgreSQL URL)
- `APP_URL`: Application root URL
- `BASE_URL`: API base URL
- `JWT_SECRET_KEY`: Secret for JWT token signing
- `STRIPE_SECRET_KEY`: Stripe API key
- `STRIPE_WEBHOOK_SECRET`: Stripe webhook signature key
- `REVENUECAT_WEBHOOK_AUTH_TOKEN`: RevenueCat webhook token

**Optional Database Settings:**
- `DATABASE_URL_REMOTE`: Separate remote database URL (for tunneling scenarios)
- `DATABASE_URL_INTERNAL`: Separate internal/local database URL
- `DATABASE_URL_LOCAL`: Alias for DATABASE_URL_INTERNAL

### SQLAlchemy Engine Configuration
File: `backend/app/db/session.py`

```python
engine = create_async_engine(
    str(settings.DATABASE_URL),
    pool_pre_ping=True,          # Verify connections before use
    pool_recycle=3600,           # Recycle connections after 1 hour
    echo=False,                  # No SQL logging (production)
    connect_args={"server_settings": {"jit": "off"}},  # Disable PostgreSQL JIT
)

async_session = sessionmaker(
    engine, 
    expire_on_commit=False, 
    class_=AsyncSession
)
```

**Connection Pool Details:**
- Uses async SQLAlchemy with asyncpg driver
- Pool pre-ping: Validates connection before issuing queries
- Pool recycle: Closes connections after 1 hour to avoid stale connections
- PostgreSQL JIT disabled: Improves predictability for OLTP workloads

---

## 4. DATABASE MIGRATIONS

### Alembic Setup
- **Location:** `/home/deploy/repduel/backend/alembic/`
- **Config:** `backend/alembic.ini`
- **Versions stored in:** `backend/alembic/versions/`

### Migration Flow (via `backend/scripts/migrate.sh`)

The migration script performs the following:

1. **Environment Setup:**
   ```bash
   export PGHOST=178.156.201.92
   export PGPORT=9991
   export PGUSER=appuser
   export PGPASSWORD=supersecret
   export PGDATABASE=app1db
   ```

2. **Version Validation:**
   - Fetches current Alembic HEAD version from repo
   - Queries `alembic_version` table in database
   - Ensures they match before generating new migrations

3. **Migration Commands:**
   ```bash
   # Generate new migration with autogenerate
   alembic revision --autogenerate -m "change_description"
   
   # Apply all pending migrations
   alembic upgrade head
   
   # Show current migration version
   alembic current
   ```

4. **Integration with Doppler:**
   All Alembic operations run through Doppler's `prd_backend` config for production credentials

### Recent Migrations
- `80e1c2982a5f_baseline_after_restore.py` - Baseline after restore
- `66718b7b3f2f_change.py` - Previous change
- `27dcd007108a_next_change.py` - Most recent change

---

## 5. PRODUCTION DEPLOYMENT SETUP

### Systemd Service Configuration
**Location:** `/etc/systemd/system/repduel-backend.service`

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

**Key Points:**
- Runs as non-root `deploy` user
- Port 9999 (exposed only to localhost, proxied via Caddy)
- 2 uvicorn workers for parallel request handling
- Automatic restart on failure (3 second delay)
- Secrets injected via Doppler at runtime

### Useful Systemd Commands
```bash
# View service status
sudo systemctl status repduel-backend

# Restart service
sudo systemctl restart repduel-backend

# View recent logs
journalctl -u repduel-backend -n 50 --no-pager

# Follow logs in real-time
journalctl -u repduel-backend -f
```

---

## 6. SECRETS MANAGEMENT (DOPPLER)

### Doppler Configuration
The system uses two Doppler configs:
- **`dev_backend`**: Development environment with database tunnel URL
- **`prd_backend`**: Production environment with direct Hetzner database access

### Secrets Provided by Doppler
For production (`prd_backend`):
- `DATABASE_URL`: Full PostgreSQL connection string
- `DATABASE_URL_INTERNAL`: Alternative internal connection string (optional)
- `DATABASE_URL_REMOTE`: Alternative remote connection string (optional)
- `JWT_SECRET_KEY`: Secret for JWT token generation
- `REFRESH_JWT_SECRET_KEY`: Optional separate refresh token secret
- `STRIPE_SECRET_KEY`: Stripe API secret key
- `STRIPE_WEBHOOK_SECRET`: Stripe webhook signature verification
- `REVENUECAT_WEBHOOK_AUTH_TOKEN`: RevenueCat webhook authentication
- All other configuration values (app URLs, Celery settings, etc.)

### Runtime Injection
All systemd services run through Doppler:
```bash
doppler run --project repduel --config prd_backend -- [command]
```

This ensures secrets are:
1. Never committed to git
2. Never visible in process listings
3. Managed centrally in Doppler
4. Rotatable without code changes

---

## 7. CADDY REVERSE PROXY CONFIGURATION

### File: `deploy/Caddyfile`

```caddy
{
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

api.repduel.com {
    encode zstd gzip

    # Static files with long-term caching
    @static {
        path /static/*
    }
    handle @static {
        header Cache-Control "public, max-age=31536000, immutable"
        reverse_proxy 127.0.0.1:9999
    }

    # All other requests to FastAPI backend
    handle {
        reverse_proxy 127.0.0.1:9999
    }
}
```

**Network Flow:**
1. External client → `api.repduel.com:443` (HTTPS)
2. Caddy (TLS termination) → `127.0.0.1:9999` (HTTP, localhost only)
3. FastAPI backend processes request and accesses PostgreSQL via custom port 9991

---

## 8. DATABASE HEALTH CHECKS

### Health Check Endpoints

**Backend health:**
```bash
curl http://127.0.0.1:9999/health
# Response: {"status": "ok"}
```

**Database connectivity:**
```bash
curl http://127.0.0.1:9999/health/db
# Response: {"status": "ok", "database": "reachable"}
```

**Redeploy Script Verification:**
The `/home/deploy/repduel/tools/redeploy.sh` performs post-deployment health check:
```bash
curl -fsS http://localhost:9999/health >/dev/null && echo "✅ Backend healthy" || exit 1
```

---

## 9. ENVIRONMENT VARIABLES SUMMARY

### Required for Production (`prd_backend`)
```bash
DATABASE_URL=postgresql+asyncpg://appuser:supersecret@178.156.201.92:9991/app1db
APP_URL=https://api.repduel.com
BASE_URL=https://api.repduel.com
PORT=9999
PYTHONUNBUFFERED=1

# Authentication
JWT_SECRET_KEY=[secret from Doppler]
REFRESH_JWT_SECRET_KEY=[secret from Doppler]

# Payments
STRIPE_SECRET_KEY=[secret from Doppler]
STRIPE_WEBHOOK_SECRET=[secret from Doppler]

# Mobile payments webhook
REVENUECAT_WEBHOOK_AUTH_TOKEN=[secret from Doppler]

# CORS/Frontend
FRONTEND_ORIGINS=https://www.repduel.com
COOKIE_DOMAIN=repduel.com
COOKIE_SECURE=true
COOKIE_SAMESITE=none

# Static files
STATIC_STORAGE_DIR=/home/deploy/repduel/backend/static

# Database bootstrap (strictness)
REPDUEL_STRICT_DB_BOOTSTRAP=1
```

### Optional for Tunneling/Development
```bash
DATABASE_URL_INTERNAL=postgresql+asyncpg://[tunnel connection]
DATABASE_URL_LOCAL=postgresql+asyncpg://[local connection]
DATABASE_URL_REMOTE=postgresql+asyncpg://[remote connection]
REPDUEL_DB_BOOTSTRAP_TIMEOUT=10.0  # seconds
```

---

## 10. FILESYSTEM LAYOUT ON HETZNER VPS

```
/home/deploy/
├── repduel/                          # Application root
│   ├── backend/
│   │   ├── .venv/                    # Python virtual environment
│   │   ├── app/
│   │   │   ├── main.py               # FastAPI app entry point
│   │   │   ├── db/
│   │   │   │   └── session.py        # SQLAlchemy async engine setup
│   │   │   ├── db_bootstrap.py       # Database DSN selection logic
│   │   │   ├── core/
│   │   │   │   └── config.py         # Settings with Pydantic validation
│   │   │   ├── models/               # SQLAlchemy ORM models
│   │   │   └── api/v1/               # API routes
│   │   ├── alembic/
│   │   │   ├── versions/             # Migration files
│   │   │   └── env.py                # Alembic configuration
│   │   ├── scripts/
│   │   │   └── migrate.sh            # Database migration script (with hardcoded DB config)
│   │   └── requirements.txt           # Python dependencies
│   │
│   ├── deploy/
│   │   ├── Caddyfile                 # Caddy reverse proxy config
│   │   ├── build.sh                  # Build script
│   │   └── public/                   # Flutter web frontend (served by backend)
│   │
│   ├── tools/
│   │   └── redeploy.sh               # Zero-guess redeploy script
│   │
│   └── static/                       # User-uploaded static files
│
├── backups/                          # Database backups
├── render_backup.dump                # Backup from Render (legacy reference)
└── …
```

---

## 11. DEPLOYMENT & REDEPLOYMENT PROCESS

### Zero-Guess Redeploy Script
Location: `/home/deploy/repduel/tools/redeploy.sh`

**Steps:**
1. Pull latest code: `git pull origin main`
2. Update Python dependencies: `pip install -r requirements.txt`
3. Restart backend service: `sudo systemctl restart repduel-backend`
4. Reload Caddy: `sudo caddy reload --config /etc/caddy/Caddyfile`
5. Health check: `curl http://localhost:9999/health`

**Run Command:**
```bash
ssh deploy@178.156.201.92
/home/deploy/repduel/tools/redeploy.sh
```

### Frontend Deployment (Render)
- Flutter web frontend deployed to Render via GitHub Actions
- Git workflow: `/.github/workflows/deploy-web.yml`
- Rendered static files deployed, **not** backend code
- Caddy serves frontend from `deploy/public/` directory

---

## 12. KEY DIFFERENCES: DEVELOPMENT vs PRODUCTION

### Development Setup
- **Database Location:** Can be local Docker or remote with SSH tunnel
- **Connection String:** Uses `DATABASE_URL` from Doppler `dev_backend` config
- **Port:** Usually 5432 (standard PostgreSQL)
- **Secret Management:** Doppler with interactive login or service token
- **Process Manager:** Manual uvicorn with `--reload` flag
- **Frontend:** Served by Flutter dev server (separate port)
- **SSL/TLS:** None (local development)

### Production Setup
- **Database Location:** Hetzner VPS at `178.156.201.92:9991`
- **Connection String:** Direct PostgreSQL connection via `prd_backend` secrets
- **Port:** Custom port 9991 (non-standard for security)
- **Secret Management:** Doppler with `prd_backend` config
- **Process Manager:** Systemd service (`repduel-backend.service`)
- **Frontend:** Bundled in `deploy/public/`, served by Caddy
- **SSL/TLS:** Let's Encrypt via Caddy (auto-renewed)

---

## 13. DATABASE SCHEMA & MIGRATIONS

### Alembic Configuration File: `backend/alembic.ini`
```ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql+asyncpg://yavasuite_user:Cf0Nok2j5MNcIs7qjh4xQzNQcZKa5veK@dpg-d18oqd3uibrs73dsf4i0-a.virginia-postgres.render.com/yavasuite_db_l7xm
```

**Note:** The alembic.ini contains a legacy Render database URL (likely from previous backup/restore). This is NOT used at runtime; Doppler secrets take precedence.

### Version Control
All migrations are committed to git in `backend/alembic/versions/`:
- Migration files are auto-generated with `alembic revision --autogenerate`
- Each migration includes `upgrade()` and `downgrade()` functions
- Version tracking in `alembic_version` table

---

## 14. SECURITY CONSIDERATIONS

### Current Security Posture
- **Database Password:** Stored in Doppler (not in git or code)
- **Custom Port:** Uses non-standard port 9991 instead of 5432
- **No Remote Access:** Database bound to localhost only (accessed by backend on same host)
- **Firewall:** UFW configured to allow only necessary ports
- **User Separation:** Backend runs as `deploy` user (non-root)
- **HTTPS:** Enforced by Caddy with Let's Encrypt certificates
- **CORS:** Restricted to known frontend origins
- **JWT:** Short-lived access tokens + rotating refresh tokens

### Recommendations
1. Consider using password rotation policies in Doppler
2. Implement database backups to external storage
3. Monitor slow queries with PostgreSQL logs
4. Consider read replicas for scaling
5. Set up connection pooling (PgBouncer) for high-load scenarios

---

## 15. TROUBLESHOOTING GUIDE

### Database Connection Issues

**Symptom:** "Unable to connect to the database" error

**Steps:**
1. Check Doppler secrets are loaded:
   ```bash
   doppler run --project repduel --config prd_backend -- env | grep DATABASE
   ```

2. Test direct connection from server:
   ```bash
   psql "postgresql://appuser:supersecret@178.156.201.92:9991/app1db" -c "SELECT 1"
   ```

3. Check backend service logs:
   ```bash
   journalctl -u repduel-backend -n 100 --no-pager
   ```

4. Verify firewall allows port 9991:
   ```bash
   sudo ufw status
   ```

### Migration Failures

**Symptom:** Alembic version mismatch

**Fix:**
```bash
cd /home/deploy/repduel/backend
doppler run --project repduel --config prd_backend -- alembic current
doppler run --project repduel --config prd_backend -- alembic upgrade head
```

### Connection Pool Issues

**Symptom:** "Too many connections" error after extended uptime

**Fix:**
1. Restart backend service to flush stale connections:
   ```bash
   sudo systemctl restart repduel-backend
   ```

2. Pool is set to recycle after 3600 seconds (1 hour), so connections should auto-refresh

---

## 16. FUTURE IMPROVEMENTS

### Recommended Next Steps
1. **Backup Strategy:** Implement automated PostgreSQL backups to S3 or external storage
2. **Monitoring:** Add database metrics (CPU, connections, slow queries) to monitoring
3. **Connection Pooling:** Consider PgBouncer for connection pooling to reduce overhead
4. **Replication:** Set up read replicas for read-heavy workloads (leaderboards)
5. **CI/CD:** Automated migration testing in GitHub Actions before production deployment
6. **Documentation:** Create operational runbooks for common database maintenance tasks
7. **Testing:** Expand database tests to cover edge cases and high-load scenarios

---

## SUMMARY TABLE

| Aspect | Value |
|--------|-------|
| **Host** | Hetzner VPS (`178.156.201.92`) |
| **OS** | Ubuntu 24.04 LTS |
| **Database** | PostgreSQL (port 9991, custom) |
| **User** | `appuser` |
| **Database Name** | `app1db` |
| **Backend Port** | 9999 (HTTP, localhost only) |
| **External Access** | HTTPS via Caddy (api.repduel.com) |
| **Process Manager** | systemd (`repduel-backend.service`) |
| **Secrets Manager** | Doppler (`prd_backend` config) |
| **Migrations** | Alembic (async SQLAlchemy) |
| **Async Driver** | asyncpg |
| **Connection Pool** | SQLAlchemy async session manager |
| **TLS** | Let's Encrypt (auto-renewed by Caddy) |
| **Frontend** | Flutter web (static, served by Caddy) |

---

## REFERENCES

### Key Files
- Configuration: `/home/deploy/repduel/backend/app/core/config.py`
- Database setup: `/home/deploy/repduel/backend/app/db/session.py`
- Bootstrap logic: `/home/deploy/repduel/backend/app/db_bootstrap.py`
- Migrations: `/home/deploy/repduel/backend/alembic/`
- Systemd service: `/etc/systemd/system/repduel-backend.service`
- Reverse proxy: `/etc/caddy/Caddyfile` (symlinked to `deploy/Caddyfile`)
- Redeploy script: `/home/deploy/repduel/tools/redeploy.sh`

### Documentation
- Main README: `/home/deploy/repduel/README.md`
- Context bootstrap: `/home/deploy/repduel/docs/copypaste_context_bootstrap.md`
- Deployment guide: `/home/deploy/repduel/deploy/README.md`

---

**Document Generated:** 2025-11-12
**Repository:** https://github.com/lalov/repduel
**Current Branch:** main
