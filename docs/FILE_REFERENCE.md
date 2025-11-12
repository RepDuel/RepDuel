# Complete File Reference

This document lists all key files related to PostgreSQL deployment with their absolute paths.

## Documentation Files (Newly Created)

### Main Documentation
- `/Users/lalov/repduel/docs/PostgreSQL_Deployment_Analysis.md` - 16-section comprehensive analysis
- `/Users/lalov/repduel/docs/DATABASE_QUICK_REFERENCE.md` - Quick lookup and commands
- `/Users/lalov/repduel/docs/ARCHITECTURE_DIAGRAM.md` - Visual diagrams and flowcharts
- `/Users/lalov/repduel/docs/README_POSTGRESQL_DOCS.md` - Documentation index and FAQ
- `/Users/lalov/repduel/docs/FILE_REFERENCE.md` - This file (complete file listing)

### Existing Documentation
- `/Users/lalov/repduel/README.md` - Platform overview and setup guide
- `/Users/lalov/repduel/deploy/README.md` - Deployment playbook
- `/Users/lalov/repduel/docs/copypaste_context_bootstrap.md` - Quick orientation
- `/Users/lalov/repduel/docs/landing-page.md` - Marketing landing page

---

## Backend Configuration Files

### Core Configuration
- `/Users/lalov/repduel/backend/app/core/config.py` - Pydantic Settings class with DATABASE_URL validation
- `/Users/lalov/repduel/backend/app/core/auth.py` - Authentication helpers
- `/Users/lalov/repduel/backend/app/core/security.py` - Security utilities
- `/Users/lalov/repduel/backend/app/core/celery_app.py` - Celery task configuration

### Database Setup
- `/Users/lalov/repduel/backend/app/db/session.py` - SQLAlchemy async engine and session setup
- `/Users/lalov/repduel/backend/app/db/base.py` - ORM base classes
- `/Users/lalov/repduel/backend/app/db_bootstrap.py` - Database DSN selection logic

### Application Entry Point
- `/Users/lalov/repduel/backend/app/main.py` - FastAPI app initialization and middleware setup

---

## Database Migration Files

### Alembic Configuration
- `/Users/lalov/repduel/backend/alembic.ini` - Alembic configuration file (contains legacy Render URL)
- `/Users/lalov/repduel/backend/alembic/env.py` - Alembic environment configuration
- `/Users/lalov/repduel/backend/alembic/script.py.mako` - Migration template

### Migration Versions
- `/Users/lalov/repduel/backend/alembic/versions/80e1c2982a5f_baseline_after_restore.py` - Baseline after restore
- `/Users/lalov/repduel/backend/alembic/versions/66718b7b3f2f_change.py` - Previous change
- `/Users/lalov/repduel/backend/alembic/versions/27dcd007108a_next_change.py` - Most recent change

### Migration Scripts
- `/Users/lalov/repduel/backend/scripts/migrate.sh` - Migration helper script (CONTAINS HARDCODED CREDENTIALS FOR DEV)

---

## Deployment & Infrastructure Files

### Reverse Proxy Configuration
- `/Users/lalov/repduel/deploy/Caddyfile` - Caddy reverse proxy configuration
- `/etc/caddy/Caddyfile` - Production symlink (on Hetzner VPS)

### Deployment Scripts
- `/Users/lalov/repduel/tools/redeploy.sh` - Zero-guess redeploy automation script
- `/Users/lalov/repduel/deploy/build.sh` - Build script

### Systemd Service (Hetzner VPS Only)
- `/etc/systemd/system/repduel-backend.service` - Systemd service definition (prod server)

---

## Backend Application Structure

### API Routes
- `/Users/lalov/repduel/backend/app/api/v1/api_router.py` - API router setup
- `/Users/lalov/repduel/backend/app/api/v1/auth.py` - Authentication endpoints
- `/Users/lalov/repduel/backend/app/api/v1/users.py` - User endpoints
- `/Users/lalov/repduel/backend/app/api/v1/payments.py` - Payment/subscription endpoints
- `/Users/lalov/repduel/backend/app/api/v1/webhooks.py` - Webhook endpoints (Stripe, RevenueCat)
- `/Users/lalov/repduel/backend/app/api/v1/social.py` - Social/leaderboard endpoints
- `/Users/lalov/repduel/backend/app/api/v1/guilds.py` - Guild endpoints
- `/Users/lalov/repduel/backend/app/api/v1/routines.py` - Routine endpoints
- `/Users/lalov/repduel/backend/app/api/v1/scenario.py` - Scenario endpoints
- `/Users/lalov/repduel/backend/app/api/v1/levels.py` - Level/rank endpoints
- `/Users/lalov/repduel/backend/app/api/v1/standards.py` - Standards endpoints
- `/Users/lalov/repduel/backend/app/api/v1/personal_best_events.py` - PR tracking endpoints
- `/Users/lalov/repduel/backend/app/api/v1/quests.py` - Quest endpoints
- `/Users/lalov/repduel/backend/app/api/v1/routine_submission.py` - Workout submission endpoints

### Data Models (SQLAlchemy ORM)
- `/Users/lalov/repduel/backend/app/models/user.py` - User model
- `/Users/lalov/repduel/backend/app/models/routine.py` - Routine model
- `/Users/lalov/repduel/backend/app/models/routine_submission.py` - Workout submission model
- `/Users/lalov/repduel/backend/app/models/scenario.py` - Scenario (ranked lift) model
- `/Users/lalov/repduel/backend/app/models/personal_best_event.py` - PR event model
- `/Users/lalov/repduel/backend/app/models/leaderboard.py` - Leaderboard model
- `/Users/lalov/repduel/backend/app/models/user_xp.py` - User XP/energy model
- `/Users/lalov/repduel/backend/app/models/guild.py` - Guild model
- `/Users/lalov/repduel/backend/app/models/social.py` - Social connections model
- `/Users/lalov/repduel/backend/app/models/associations.py` - Association table models
- `/Users/lalov/repduel/backend/app/models/equipment.py` - Equipment model
- `/Users/lalov/repduel/backend/app/models/muscle.py` - Muscle group model
- `/Users/lalov/repduel/backend/app/models/quest.py` - Quest model
- `/Users/lalov/repduel/backend/app/models/energy_history.py` - Energy score history
- `/Users/lalov/repduel/backend/app/models/daily_workout_aggregate.py` - Workout aggregation

### Pydantic Schemas
- `/Users/lalov/repduel/backend/app/schemas/user.py` - User request/response schemas
- `/Users/lalov/repduel/backend/app/schemas/routine.py` - Routine schemas
- `/Users/lalov/repduel/backend/app/schemas/routine_submission.py` - Submission schemas
- `/Users/lalov/repduel/backend/app/schemas/payment.py` - Payment schemas
- `/Users/lalov/repduel/backend/app/schemas/social.py` - Social schemas
- `/Users/lalov/repduel/backend/app/schemas/token.py` - JWT token schemas
- `/Users/lalov/repduel/backend/app/schemas/quest.py` - Quest schemas
- `/Users/lalov/repduel/backend/app/schemas/guild.py` - Guild schemas
- `/Users/lalov/repduel/backend/app/schemas/level.py` - Level schemas
- `/Users/lalov/repduel/backend/app/schemas/personal_best_event.py` - PR event schemas

### Business Logic Services
- `/Users/lalov/repduel/backend/app/services/user_service.py` - User business logic
- `/Users/lalov/repduel/backend/app/services/score_service.py` - Energy/score calculations
- `/Users/lalov/repduel/backend/app/services/level_service.py` - Level progression logic
- `/Users/lalov/repduel/backend/app/services/rank_service.py` - Rank calculations
- `/Users/lalov/repduel/backend/app/services/rate_limiter.py` - Rate limiting
- `/Users/lalov/repduel/backend/app/services/guild_service.py` - Guild management
- `/Users/lalov/repduel/backend/app/services/social_service.py` - Social features
- `/Users/lalov/repduel/backend/app/services/dots_service.py` - DOTS score calculations
- `/Users/lalov/repduel/backend/app/services/energy_service.py` - Energy score calculations
- `/Users/lalov/repduel/backend/app/services/bodyweight_benchmarks.py` - Bodyweight standards

### Dependencies & Utilities
- `/Users/lalov/repduel/backend/app/api/v1/deps.py` - Dependency injection helpers
- `/Users/lalov/repduel/backend/app/utils/datetime.py` - Date/time utilities

---

## Dependencies & Configuration

### Python Requirements
- `/Users/lalov/repduel/backend/requirements.txt` - Python package dependencies
  - Key packages: FastAPI, SQLAlchemy, asyncpg, Alembic, pytest, stripe, etc.

### Frontend Configuration
- `/Users/lalov/repduel/frontend/pubspec.yaml` - Flutter/Dart dependencies
- `/Users/lalov/repduel/frontend/.env` - Frontend environment variables

### Project Configuration
- `/Users/lalov/repduel/render.yaml` - Render deployment configuration
- `/Users/lalov/repduel/Makefile` - Build automation
- `/Users/lalov/repduel/.github/workflows/deploy-web.yml` - CI/CD workflow
- `/Users/lalov/repduel/.gitignore` - Git ignore rules

---

## Testing Files

- `/Users/lalov/repduel/backend/pytest.ini` - Pytest configuration
- `/Users/lalov/repduel/backend/tests/conftest.py` - Pytest fixtures
- `/Users/lalov/repduel/backend/tests/test_api/test_payments_webhook.py` - Payment webhook tests
- `/Users/lalov/repduel/backend/tests/test_api/test_social_api.py` - Social API tests
- `/Users/lalov/repduel/backend/tests/test_api/test_routines_share_api.py` - Routine sharing tests
- `/Users/lalov/repduel/backend/tests/test_api/test_levels_api.py` - Level API tests

---

## Static Files & Assets

- `/Users/lalov/repduel/backend/static/` - User-uploaded files (on production server)
- `/Users/lalov/repduel/deploy/public/` - Flutter web build (served by backend and Caddy)
- `/Users/lalov/repduel/frontend/assets/` - Flutter app assets

---

## Database-Related Absolute Paths (On Hetzner VPS)

### Production Server Directory Structure
```
/home/deploy/
├── repduel/
│   ├── backend/
│   │   ├── .venv/bin/python          - Python virtual environment
│   │   ├── .venv/bin/uvicorn         - Web server binary
│   │   ├── .venv/bin/alembic         - Migration tool
│   │   ├── app/core/config.py        - Settings with DATABASE_URL
│   │   ├── db/session.py             - SQLAlchemy setup
│   │   ├── db_bootstrap.py           - DSN selection
│   │   └── alembic/versions/         - Migrations
│   ├── deploy/Caddyfile              - Reverse proxy config
│   ├── tools/redeploy.sh             - Deploy automation
│   └── static/                       - Uploaded files
├── backups/                          - Backup directory
└── render_backup.dump                - Legacy backup
```

### Database Logs (On Production Server)
- `/var/log/postgresql/` - PostgreSQL logs
- Via journalctl: `journalctl -u repduel-backend -f` - Backend logs

---

## Environment Variables (From Doppler)

### All Variables Provided by Doppler
File location: Managed by Doppler (prd_backend config)
- DATABASE_URL
- JWT_SECRET_KEY
- REFRESH_JWT_SECRET_KEY
- STRIPE_SECRET_KEY
- STRIPE_WEBHOOK_SECRET
- REVENUECAT_WEBHOOK_AUTH_TOKEN
- APP_URL
- BASE_URL
- STATIC_STORAGE_DIR
- STATIC_PUBLIC_BASE
- STATIC_PREFER_CDN
- ALGORITHM
- ACCESS_TOKEN_EXPIRE_MINUTES
- REFRESH_TOKEN_EXPIRE_DAYS
- FRONTEND_ORIGINS
- COOKIE_SAMESITE
- COOKIE_SECURE
- COOKIE_DOMAIN
- CELERY_BROKER_URL
- CELERY_RESULT_BACKEND
- CELERY_TASK_DEFAULT_QUEUE
- CELERY_TASK_ALWAYS_EAGER
- ... (20+ additional variables)

---

## Summary

**Total Key Files Documented:** 100+

**Documentation Created:** 5 comprehensive guides (1,500+ lines)

**Key Configuration Files:** 3 (config.py, session.py, db_bootstrap.py)

**Infrastructure Files:** 4 (Caddyfile, redeploy.sh, systemd service, alembic.ini)

**Database Models:** 15+ SQLAlchemy ORM models

**API Routes:** 12+ versioned endpoints

**Services:** 10+ business logic services

---

**Last Updated:** 2025-11-12
**Status:** Complete and Ready for Reference
