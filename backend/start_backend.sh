#!/usr/bin/env bash
set -euo pipefail
export USE_SSH_TUNNEL="${USE_SSH_TUNNEL:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
echo "--- Starting RepDuel Backend (Doppler dev) ---"
if ! command -v doppler >/dev/null 2>&1; then echo "doppler CLI not found"; exit 1; fi
if ! doppler --version >/dev/null 2>&1; then echo "doppler CLI not working"; exit 1; fi
if [[ -z "${DOPPLER_TOKEN:-}" ]]; then if ! doppler whoami >/dev/null 2>&1; then echo "Not logged into Doppler"; exit 1; fi; fi
if [[ ! -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then echo "Virtual env missing at $PROJECT_ROOT/.venv"; exit 1; fi
source "$PROJECT_ROOT/.venv/bin/activate"
SSH_TARGET_DEFAULT="deploy@178.156.201.92"
SSH_TARGET="${SSH_TARGET:-$(doppler secrets get SSH_TARGET --project repduel --config dev_backend --plain 2>/dev/null || echo "$SSH_TARGET_DEFAULT")}"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-$(doppler secrets get SSH_IDENTITY_FILE --project repduel --config dev_backend --plain 2>/dev/null || echo "$HOME/.ssh/repduel_dev")}"
REMOTE_DB_HOST="${REMOTE_DB_HOST:-$(doppler secrets get REMOTE_DB_HOST --project repduel --config dev_backend --plain 2>/dev/null || echo 127.0.0.1)}"
REMOTE_DB_PORT="${REMOTE_DB_PORT:-$(doppler secrets get REMOTE_DB_PORT --project repduel --config dev_backend --plain 2>/dev/null || echo 5432)}"
LOCAL_DB_HOST="${LOCAL_DB_HOST:-$(doppler secrets get LOCAL_DB_HOST --project repduel --config dev_backend --plain 2>/dev/null || echo 127.0.0.1)}"
LOCAL_DB_PORT="${LOCAL_DB_PORT:-$(doppler secrets get LOCAL_DB_PORT --project repduel --config dev_backend --plain 2>/dev/null || echo 5433)}"
DATABASE_URL_LOCAL="${DATABASE_URL_LOCAL:-$(doppler secrets get DATABASE_URL_LOCAL --project repduel --config dev_backend --plain 2>/dev/null || true)}"
DATABASE_URL_REMOTE="${DATABASE_URL_REMOTE:-$(doppler secrets get DATABASE_URL_REMOTE --project repduel --config dev_backend --plain 2>/dev/null || true)}"
if [[ -z "${DATABASE_URL_LOCAL:-}" && -z "${DATABASE_URL_REMOTE:-}" ]]; then echo "DATABASE_URL_LOCAL or DATABASE_URL_REMOTE must be set in Doppler"; exit 1; fi
TUNNEL_ACTIVE=0
TUNNEL_PID=""
cleanup(){ if [[ -n "${TUNNEL_PID:-}" ]]; then kill "$TUNNEL_PID" >/dev/null 2>&1 || true; wait "$TUNNEL_PID" 2>/dev/null || true; fi; }
trap cleanup EXIT
if [[ "${USE_SSH_TUNNEL}" == "1" ]]; then
  if ! command -v ssh >/dev/null 2>&1; then echo "ssh not found"; exit 1; fi
  if ! command -v nc >/dev/null 2>&1; then echo "nc not found"; exit 1; fi
  if [[ -z "${SSH_TARGET:-}" ]]; then echo "SSH_TARGET required for tunnel"; exit 1; fi
  SSH_CMD=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o ExitOnFailure=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -N -L "${LOCAL_DB_HOST}:${LOCAL_DB_PORT}:${REMOTE_DB_HOST}:${REMOTE_DB_PORT}")
  if [[ -n "${SSH_IDENTITY_FILE:-}" && -f "${SSH_IDENTITY_FILE}" ]]; then SSH_CMD+=(-i "$SSH_IDENTITY_FILE"); fi
  SSH_CMD+=("${SSH_TARGET}")
  "${SSH_CMD[@]}" &
  TUNNEL_PID=$!
  sleep 1
  if ! kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then echo "Failed to establish SSH tunnel"; exit 1; fi
  if ! nc -z "${LOCAL_DB_HOST}" "${LOCAL_DB_PORT}" >/dev/null 2>&1; then echo "Tunnel health check failed on ${LOCAL_DB_HOST}:${LOCAL_DB_PORT}"; exit 1; fi
  TUNNEL_ACTIVE=1
fi
cd "$SCRIPT_DIR"
export REPDUEL_STRICT_DB_BOOTSTRAP="${REPDUEL_STRICT_DB_BOOTSTRAP:-1}"
RUN_CMD=(env)
if [[ "$TUNNEL_ACTIVE" == "1" && -n "${DATABASE_URL_LOCAL:-}" ]]; then
  RUN_CMD+=("DATABASE_URL=${DATABASE_URL_LOCAL}")
elif [[ -n "${DATABASE_URL_REMOTE:-}" ]]; then
  RUN_CMD+=("DATABASE_URL=${DATABASE_URL_REMOTE}")
fi
RUN_CMD+=(uvicorn app.main:app --reload --host 127.0.0.1 --port 8000)
doppler run --project repduel --config dev_backend -- "${RUN_CMD[@]}"
