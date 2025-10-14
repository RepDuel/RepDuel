#!/usr/bin/env bash
set -e
. .venv/bin/activate
export PGHOST=178.156.201.92
export PGPORT=9991
export PGUSER=appuser
export PGPASSWORD=supersecret
export PGDATABASE=app1db
export DBURL="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE"
H1=$(doppler run --project repduel --config dev_backend -- .venv/bin/alembic heads | awk "{print \$1}")
V1=$(psql "$DBURL" -Atc "select version_num from alembic_version")
test -n "$H1" && test -n "$V1"
if [ "$H1" != "$V1" ]; then echo "Repo head $H1 != DB $V1"; exit 1; fi
doppler run --project repduel --config dev_backend -- .venv/bin/alembic revision --autogenerate -m "${1:-change}"
doppler run --project repduel --config dev_backend -- .venv/bin/alembic upgrade head
doppler run --project repduel --config dev_backend -- .venv/bin/alembic current
