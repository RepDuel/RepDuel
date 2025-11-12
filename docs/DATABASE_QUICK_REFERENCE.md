# PostgreSQL Quick Reference

## Production Connection Details

```
Host:     178.156.201.92
Port:     9991 (custom, non-standard)
User:     appuser
Password: supersecret (from Doppler)
Database: app1db
URL:      postgresql+asyncpg://appuser:supersecret@178.156.201.92:9991/app1db
```

## Key Files

| File | Purpose |
|------|---------|
| `backend/app/core/config.py` | Settings & environment configuration |
| `backend/app/db/session.py` | SQLAlchemy async engine setup |
| `backend/app/db_bootstrap.py` | Database DSN selection logic |
| `backend/alembic/` | Database migrations |
| `backend/scripts/migrate.sh` | Migration script with DB config |
| `deploy/Caddyfile` | Reverse proxy configuration |
| `tools/redeploy.sh` | Deployment automation script |

## Connection Flow

```
Client
  ↓
api.repduel.com:443 (HTTPS)
  ↓
Caddy (TLS termination)
  ↓
127.0.0.1:9999 (FastAPI backend)
  ↓
178.156.201.92:9991 (PostgreSQL)
```

## Environment Variables

**Required (from Doppler `prd_backend`):**
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, etc.

**Optional:**
- `DATABASE_URL_INTERNAL`: Alternative internal connection (local tunnel)
- `DATABASE_URL_REMOTE`: Alternative remote connection
- `REPDUEL_STRICT_DB_BOOTSTRAP`: Enable strict mode (default: 1)

## Database Bootstrap Logic

1. Try `DATABASE_URL_INTERNAL` (preferred)
2. Try `DATABASE_URL_LOCAL` 
3. Fallback to `DATABASE_URL`
4. If remote fails, try `DATABASE_URL_REMOTE`
5. Return first successful connection

**Strict mode** (`REPDUEL_STRICT_DB_BOOTSTRAP=1`): Fail to start if no connection succeeds

## SQLAlchemy Configuration

```python
engine = create_async_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,        # Validate connections
    pool_recycle=3600,         # Recycle after 1 hour
    echo=False,                # No SQL logging
    connect_args={"server_settings": {"jit": "off"}}  # Disable JIT
)
```

## Systemd Service

**Service name:** `repduel-backend`
**Run command:** `doppler run --project repduel --config prd_backend -- uvicorn app.main:app --port 9999 --workers 2`
**Port:** 9999 (HTTP, localhost only)
**User:** `deploy` (non-root)

**Commands:**
```bash
sudo systemctl status repduel-backend
sudo systemctl restart repduel-backend
sudo systemctl stop repduel-backend
journalctl -u repduel-backend -f    # Follow logs
journalctl -u repduel-backend -n 100 --no-pager
```

## Deployment

### Redeploy Changes
```bash
ssh deploy@178.156.201.92
/home/deploy/repduel/tools/redeploy.sh
```

**Steps automated by redeploy.sh:**
1. `git pull origin main`
2. `pip install -r backend/requirements.txt`
3. `sudo systemctl restart repduel-backend`
4. `sudo caddy reload --config /etc/caddy/Caddyfile`
5. Health check via `curl http://localhost:9999/health`

### Database Migrations
```bash
cd /home/deploy/repduel/backend
doppler run --project repduel --config prd_backend -- alembic upgrade head
```

## Health Checks

**Backend service:**
```bash
curl http://127.0.0.1:9999/health
# {"status": "ok"}
```

**Database connectivity:**
```bash
curl http://127.0.0.1:9999/health/db
# {"status": "ok", "database": "reachable"}
```

## Secrets Management

All production secrets managed by **Doppler** project `repduel`, config `prd_backend`:
- Database URL (never in git)
- JWT secrets
- Stripe credentials
- RevenueCat webhooks
- All environment variables

## Troubleshooting

### Database Connection Error

```bash
# Verify Doppler secrets
doppler run --project repduel --config prd_backend -- env | grep DATABASE

# Test direct connection
psql "postgresql://appuser:supersecret@178.156.201.92:9991/app1db" -c "SELECT 1"

# Check service logs
journalctl -u repduel-backend -n 100 --no-pager

# Verify firewall (port 9991 should be accessible)
sudo ufw status
```

### Service Won't Start

```bash
# Check syntax errors
journalctl -u repduel-backend -n 50 --no-pager

# Manually test startup
cd /home/deploy/repduel/backend
doppler run --project repduel --config prd_backend -- python -c "from app.main import app; print('OK')"
```

### Connection Pool Issues

```bash
# Restart to flush stale connections
sudo systemctl restart repduel-backend

# Check active connections (from server)
psql "postgresql://appuser:supersecret@178.156.201.92:9991/app1db" -c "SELECT * FROM pg_stat_activity WHERE datname='app1db';"
```

## Development Setup

For local development with remote Hetzner database:

```bash
# Typical Doppler config uses tunnel (see README.md for details)
# The migrate.sh script shows direct connection for reference only:

export PGHOST=178.156.201.92
export PGPORT=9991
export PGUSER=appuser
export PGPASSWORD=supersecret
export PGDATABASE=app1db

# In development, use Doppler for secrets instead
make backend   # Runs with Doppler dev_backend config
```

## File Locations

```
/home/deploy/repduel/
├── backend/
│   ├── app/main.py              # FastAPI app entry
│   ├── app/db/session.py        # SQLAlchemy setup
│   ├── app/db_bootstrap.py      # DSN selection
│   ├── app/core/config.py       # Settings
│   ├── alembic/                 # Migrations
│   └── scripts/migrate.sh       # Migration helper
├── deploy/
│   ├── Caddyfile                # Reverse proxy
│   └── README.md                # Deployment playbook
├── tools/
│   └── redeploy.sh              # Deploy automation
└── static/                      # User uploads
```

## Connection Limits

**SQLAlchemy defaults:**
- Pool size: 5 connections
- Max overflow: 10
- Pool recycle: 3600 seconds (1 hour)
- Pool pre-ping: Enabled

These are suitable for typical OLTP workloads. Adjust in `backend/app/db/session.py` if needed.

## Monitoring Checklist

- [ ] Backend service running: `sudo systemctl status repduel-backend`
- [ ] Health check passing: `curl http://127.0.0.1:9999/health`
- [ ] DB health check passing: `curl http://127.0.0.1:9999/health/db`
- [ ] Caddy active: `sudo caddy version && sudo caddy validate --config /etc/caddy/Caddyfile`
- [ ] Doppler secrets loaded: Check journalctl logs for "Database DSN selected"
- [ ] Recent logs clean: `journalctl -u repduel-backend -n 50 --no-pager | grep -E "ERROR|WARNING"`

---

**Last Updated:** 2025-11-12  
**Database Version:** PostgreSQL (version running on Hetzner)  
**Driver:** asyncpg  
**ORM:** SQLAlchemy 2.0+ (async)
