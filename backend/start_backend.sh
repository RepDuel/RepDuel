#!/usr/bin/env bash
set -euo pipefail

# Default: use the SSH tunnel unless explicitly disabled
export USE_SSH_TUNNEL="${USE_SSH_TUNNEL:-1}"

# Default SSH target to the Hetzner host if not provided (macOS/Linux $USER assumed)
: "${SSH_TARGET:=${USER:-$(whoami)}@178.156.201.92}"

echo "--- Starting RepDuel Backend (Doppler dev) ---"

if ! command -v doppler >/dev/null 2>&1; then
  echo "doppler CLI not found. Install via: brew install dopplerhq/cli/doppler"; exit 1
fi

if ! doppler --version >/dev/null 2>&1; then
  echo "doppler CLI not working."; exit 1
fi

if [[ -z "${DOPPLER_TOKEN:-}" ]]; then
  if ! doppler whoami >/dev/null 2>&1; then
    echo "Not logged into Doppler. Run: doppler login"; exit 1
  fi
fi

# Fail fast if DATABASE_URL missing
doppler secrets get DATABASE_URL --project repduel --config dev_backend >/dev/null

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

if [[ ! -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
  echo "Virtual env not found at $PROJECT_ROOT/.venv. Create it and install deps."; exit 1
fi
source "$PROJECT_ROOT/.venv/bin/activate"

# --- Load optional tunnel and database settings from Doppler if not already set ---
SSH_TARGET="${SSH_TARGET:-$(doppler secrets get SSH_TARGET --project repduel --config dev_backend --plain 2>/dev/null || true)}"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-$(doppler secrets get SSH_IDENTITY_FILE --project repduel --config dev_backend --plain 2>/dev/null || true)}"
REMOTE_DB_HOST="${REMOTE_DB_HOST:-$(doppler secrets get REMOTE_DB_HOST --project repduel --config dev_backend --plain 2>/dev/null || true)}"
REMOTE_DB_PORT="${REMOTE_DB_PORT:-$(doppler secrets get REMOTE_DB_PORT --project repduel --config dev_backend --plain 2>/dev/null || true)}"
LOCAL_DB_HOST="${LOCAL_DB_HOST:-$(doppler secrets get LOCAL_DB_HOST --project repduel --config dev_backend --plain 2>/dev/null || true)}"
LOCAL_DB_PORT="${LOCAL_DB_PORT:-$(doppler secrets get LOCAL_DB_PORT --project repduel --config dev_backend --plain 2>/dev/null || true)}"
DATABASE_URL_LOCAL="${DATABASE_URL_LOCAL:-$(doppler secrets get DATABASE_URL_LOCAL --project repduel --config dev_backend --plain 2>/dev/null || true)}"
DATABASE_URL_REMOTE="${DATABASE_URL_REMOTE:-$(doppler secrets get DATABASE_URL_REMOTE --project repduel --config dev_backend --plain 2>/dev/null || true)}"
# -------------------------------------------------------------------------------

if [[ -z "${DATABASE_URL_LOCAL:-}" && -z "${DATABASE_URL_REMOTE:-}" ]]; then
  echo "DATABASE_URL_LOCAL or DATABASE_URL_REMOTE must be configured in Doppler."; exit 1
fi

export DATABASE_URL_LOCAL DATABASE_URL_REMOTE

TUNNEL_ACTIVE=0

TUNNEL_PID=""

cleanup() {
  if [[ -n "$TUNNEL_PID" ]]; then
    echo "Closing SSH tunnel (PID $TUNNEL_PID)..."
    kill "$TUNNEL_PID" >/dev/null 2>&1 || true
    wait "$TUNNEL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ "${USE_SSH_TUNNEL:-1}" == "1" ]]; then
  if ! command -v ssh >/dev/null 2>&1; then
    echo "ssh command not found. Install OpenSSH client to use USE_SSH_TUNNEL."; exit 1
  fi

  if ! command -v nc >/dev/null 2>&1; then
    echo "nc command not found. Install netcat (nc) for tunnel verification."; exit 1
  fi

  if [[ -z "${SSH_TARGET:-}" ]]; then
    echo "SSH_TARGET is required when USE_SSH_TUNNEL=1."; exit 1
  fi

  # Set sane defaults if not provided by env/Doppler
  REMOTE_DB_HOST="${REMOTE_DB_HOST:-127.0.0.1}"
  REMOTE_DB_PORT="${REMOTE_DB_PORT:-5432}"      # remote PG port on the server
  LOCAL_DB_HOST="${LOCAL_DB_HOST:-127.0.0.1}"   # local bind
  LOCAL_DB_PORT="${LOCAL_DB_PORT:-5433}"        # avoid clashing with local PG

  echo "Creating SSH tunnel ${LOCAL_DB_HOST}:${LOCAL_DB_PORT} -> ${REMOTE_DB_HOST}:${REMOTE_DB_PORT} via ${SSH_TARGET}..."

  SSH_CMD=(
    ssh
    -o BatchMode=yes
    -o IdentitiesOnly=yes
    -o ExitOnForwardFailure=yes
    -o ServerAliveInterval=30
    -o ServerAliveCountMax=3
    -N
    -L "${LOCAL_DB_HOST}:${LOCAL_DB_PORT}:${REMOTE_DB_HOST}:${REMOTE_DB_PORT}"
  )

  if [[ -n "${SSH_IDENTITY_FILE:-}" ]]; then
    SSH_CMD+=(-i "$SSH_IDENTITY_FILE")
  fi

  if [[ -n "${SSH_EXTRA_OPTS:-}" ]]; then
    # shellcheck disable=SC2206
    SSH_CMD+=(${SSH_EXTRA_OPTS})
  fi

  SSH_CMD+=("${SSH_TARGET}")

  "${SSH_CMD[@]}" &
  TUNNEL_PID=$!
  sleep 1

  if ! kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then
    echo "Failed to establish SSH tunnel."; exit 1
  fi

  if ! nc -z "$LOCAL_DB_HOST" "$LOCAL_DB_PORT" >/dev/null 2>&1; then
    echo "Tunnel failed health check on ${LOCAL_DB_HOST}:${LOCAL_DB_PORT}."
    kill "$TUNNEL_PID" 2>/dev/null || true
    exit 1
  fi

  TUNNEL_ACTIVE=1
fi

cd "$SCRIPT_DIR"

export TUNNEL_ACTIVE
export REPDUEL_STRICT_DB_BOOTSTRAP=1

RUN_CMD=(env)

if [[ "$TUNNEL_ACTIVE" == "1" && -n "${DATABASE_URL_LOCAL:-}" ]]; then
  RUN_CMD+=("DATABASE_URL=${DATABASE_URL_LOCAL}")
elif [[ -n "${DATABASE_URL_REMOTE:-}" ]]; then
  RUN_CMD+=("DATABASE_URL=${DATABASE_URL_REMOTE}")
fi

RUN_CMD+=(
  uvicorn
  app.main:app
  --reload
  --host
  127.0.0.1
  --port
  8000
)

doppler run --project repduel --config dev_backend -- "${RUN_CMD[@]}"
