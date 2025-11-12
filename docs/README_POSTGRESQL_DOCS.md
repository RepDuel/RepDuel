# PostgreSQL Deployment Documentation Index

This directory contains comprehensive documentation about RepDuel's PostgreSQL database deployment, configuration, and operations.

## Documentation Files

### 1. **PostgreSQL_Deployment_Analysis.md** (Main Reference)
Comprehensive 16-section analysis covering:
- Database deployment configuration (Hetzner VPS, custom port 9991)
- Database bootstrap logic and connection selection
- FastAPI backend configuration and SQLAlchemy setup
- Database migrations with Alembic
- Production deployment setup (systemd service)
- Secrets management via Doppler
- Caddy reverse proxy configuration
- Health checks and monitoring
- Environment variables summary
- Filesystem layout on production server
- Deployment and redeployment process
- Development vs production differences
- Security considerations and recommendations
- Troubleshooting guide
- Future improvement suggestions
- Summary table of all key components

**Use this when:** You need detailed understanding of how the database is deployed and configured.

### 2. **DATABASE_QUICK_REFERENCE.md** (Quick Lookup)
Quick reference guide with:
- Production connection details (host, port, user, database)
- Key files and their purposes
- Connection flow diagram
- Environment variables
- Database bootstrap logic summary
- SQLAlchemy configuration
- Systemd service commands
- Deployment scripts and commands
- Health check endpoints
- Secrets management
- Troubleshooting quick fixes
- Development setup notes
- File locations
- Connection pool limits
- Monitoring checklist

**Use this when:** You need to quickly look up a command, configuration detail, or troubleshooting step.

### 3. **ARCHITECTURE_DIAGRAM.md** (Visual Reference)
Visual representation of the system including:
- System overview ASCII diagram
- Complete request/response data flow
- Configuration layers diagram
- Deployment process flowchart
- Database connection fallback logic
- Security architecture diagram
- Deployment topology summary table

**Use this when:** You want to understand the system architecture or data flow visually.

## Quick Facts

| Item | Value |
|------|-------|
| **Database Host** | Hetzner VPS (178.156.201.92) |
| **Database Port** | 9991 (custom, non-standard) |
| **Database User** | appuser |
| **Database Name** | app1db |
| **Backend Host** | localhost (127.0.0.1) |
| **Backend Port** | 9999 (HTTP, TLS via Caddy) |
| **Operating System** | Ubuntu 24.04 LTS |
| **Process Manager** | systemd (repduel-backend.service) |
| **Secrets Manager** | Doppler (prd_backend config) |
| **ORM** | SQLAlchemy 2.0+ (async) |
| **Database Driver** | asyncpg |
| **Web Framework** | FastAPI |
| **Reverse Proxy** | Caddy (api.repduel.com) |
| **SSL/TLS** | Let's Encrypt (auto-renewed) |
| **Connection Pool** | SQLAlchemy async with pre-ping & hourly recycle |

## Key Files in Repository

```
backend/
├── app/
│   ├── core/config.py           ← Settings (DATABASE_URL, secrets)
│   ├── db/session.py            ← SQLAlchemy engine setup
│   ├── db_bootstrap.py          ← Database DSN selection logic
│   └── main.py                  ← FastAPI app entry point
├── alembic/
│   ├── versions/                ← Migration files (git-tracked)
│   └── env.py                   ← Alembic configuration
├── scripts/
│   └── migrate.sh               ← Migration helper script
└── requirements.txt             ← Python dependencies (includes asyncpg, sqlalchemy)

deploy/
├── Caddyfile                    ← Reverse proxy config (api.repduel.com)
└── README.md                    ← Deployment playbook

tools/
└── redeploy.sh                  ← Zero-guess redeploy script
```

## Common Tasks

### Check Database Status
```bash
# From production server (178.156.201.92)
curl http://127.0.0.1:9999/health/db
```

### Restart Backend Service
```bash
ssh deploy@178.156.201.92
sudo systemctl restart repduel-backend
```

### View Logs
```bash
ssh deploy@178.156.201.92
journalctl -u repduel-backend -f
```

### Redeploy Code Changes
```bash
ssh deploy@178.156.201.92
/home/deploy/repduel/tools/redeploy.sh
```

### Run Database Migrations
```bash
ssh deploy@178.156.201.92
cd /home/deploy/repduel/backend
doppler run --project repduel --config prd_backend -- alembic upgrade head
```

### Test Database Connection
```bash
ssh deploy@178.156.201.92
psql "postgresql://appuser:supersecret@178.156.201.92:9991/app1db" -c "SELECT 1"
```

## Development Setup

For local development connecting to the Hetzner database:

```bash
# 1. Install dependencies
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Authenticate with Doppler
doppler login
doppler setup --project repduel --config dev_backend

# 3. Run migrations (connects via SSH tunnel)
make backend  # Starts dev server with Doppler-injected secrets

# 4. Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

The development Doppler config (`dev_backend`) includes an SSH tunnel to the Hetzner database. See main README.md for detailed setup instructions.

## Production Deployment Flow

```
1. Push to GitHub main branch
2. Optional: Run redeploy script
   ssh deploy@178.156.201.92
   /home/deploy/repduel/tools/redeploy.sh

3. Script automatically:
   - Pulls latest code
   - Installs dependencies
   - Restarts backend service
   - Reloads Caddy
   - Runs health checks

4. Secrets loaded from Doppler at service startup
   (no manual secret management needed)
```

## Monitoring

**Health Endpoints:**
- `http://127.0.0.1:9999/health` - Backend health
- `http://127.0.0.1:9999/health/db` - Database connectivity
- `http://127.0.0.1:9999/health/queue` - Celery task queue

**Log Files:**
- Service logs: `journalctl -u repduel-backend`
- PostgreSQL logs: Check `/var/log/postgresql/` on VPS

**Metrics to Watch:**
- Backend service uptime
- Database connection pool usage
- Query performance
- Disk space (backups)
- Network connectivity to 178.156.201.92

## Security Notes

- Database password stored in Doppler (never in code/git)
- Custom port 9991 (non-standard for obscurity)
- Database accessible only from localhost (no remote connections)
- Backend runs as `deploy` user (non-root)
- All external traffic goes through Caddy (TLS termination)
- Connection pool validates connections before use
- Parameterized SQL queries (no injection risk)

## Troubleshooting Quick Links

- **Database connection refused?** → Check firewall, port 9991 open
- **Service won't start?** → Check `journalctl -u repduel-backend -n 50`
- **Migrations failing?** → Verify Doppler secrets loaded, run `alembic current`
- **Pool exhausted?** → Restart service to flush stale connections
- **High query latency?** → Check PostgreSQL logs, consider connection pooling upgrade

## Related Documentation

- **Main README:** `/README.md` - Platform overview, setup guides
- **Deployment Guide:** `/deploy/README.md` - Infrastructure operations
- **Context Bootstrap:** `/docs/copypaste_context_bootstrap.md` - Quick orientation

## FAQ

**Q: Where does the database run?**
A: Hetzner VPS (IP: 178.156.201.92), Ubuntu 24.04 LTS, port 9991

**Q: How are secrets managed?**
A: Doppler project `repduel`, config `prd_backend`. Injected at runtime, never in git.

**Q: Can I connect to the database remotely?**
A: The database is accessible only from the same server (localhost). For development, use SSH tunneling through Doppler.

**Q: How do I deploy code changes?**
A: `ssh deploy@178.156.201.92` then `/home/deploy/repduel/tools/redeploy.sh`

**Q: What happens if the backend crashes?**
A: Systemd automatically restarts it (with 3-second delay). Check logs with journalctl.

**Q: How are database migrations applied?**
A: Via Alembic. Manually on VPS: `alembic upgrade head`. Or automatically in CI/CD pipelines.

**Q: Is the database backed up?**
A: There's a `render_backup.dump` file on the server (legacy). Implement automated backups to S3 or external storage.

**Q: How do I scale the database?**
A: Consider read replicas, connection pooling (PgBouncer), or upgrade Hetzner plan. Monitor with PostgreSQL metrics.

---

**Last Updated:** 2025-11-12  
**Status:** Active Production  
**Maintainer:** RepDuel Operations
