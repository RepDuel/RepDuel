#!/usr/bin/env bash
set -euo pipefail

export USE_SSH_TUNNEL="${USE_SSH_TUNNEL:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

_fetch_secret(){
  local key="$1"
  doppler secrets get "$key" --project repduel --config dev_backend --plain 2>/dev/null || true
}

_echo_err(){
  printf '%s\n' "$*" >&2
}

echo "--- Starting RepDuel Backend (Doppler dev) ---"
if ! command -v doppler >/dev/null 2>&1; then _echo_err "doppler CLI not found"; exit 1; fi
if ! doppler --version >/dev/null 2>&1; then _echo_err "doppler CLI not working"; exit 1; fi
if [[ -z "${DOPPLER_TOKEN:-}" ]]; then if ! doppler whoami >/dev/null 2>&1; then _echo_err "Not logged into Doppler"; exit 1; fi; fi
if [[ ! -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then _echo_err "Virtual env missing at $PROJECT_ROOT/.venv"; exit 1; fi
source "$PROJECT_ROOT/.venv/bin/activate"

SSH_TARGET_DEFAULT="deploy@178.156.201.92"
SSH_TARGET="${SSH_TARGET:-$(_fetch_secret SSH_TARGET)}"
if [[ -z "${SSH_TARGET:-}" ]]; then SSH_TARGET="$SSH_TARGET_DEFAULT"; fi
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-$(_fetch_secret SSH_IDENTITY_FILE)}"
if [[ -z "${SSH_IDENTITY_FILE:-}" ]]; then SSH_IDENTITY_FILE="$HOME/.ssh/repduel_dev"; fi
REMOTE_DB_HOST="${REMOTE_DB_HOST:-$(_fetch_secret REMOTE_DB_HOST)}"
REMOTE_DB_PORT="${REMOTE_DB_PORT:-$(_fetch_secret REMOTE_DB_PORT)}"
LOCAL_DB_HOST="${LOCAL_DB_HOST:-$(_fetch_secret LOCAL_DB_HOST)}"
if [[ -z "${LOCAL_DB_HOST:-}" ]]; then LOCAL_DB_HOST="127.0.0.1"; fi
LOCAL_DB_PORT="${LOCAL_DB_PORT:-$(_fetch_secret LOCAL_DB_PORT)}"
if [[ -z "${LOCAL_DB_PORT:-}" ]]; then LOCAL_DB_PORT="5433"; fi
DATABASE_URL_LOCAL="${DATABASE_URL_LOCAL:-$(_fetch_secret DATABASE_URL_LOCAL)}"
DATABASE_URL_REMOTE="${DATABASE_URL_REMOTE:-$(_fetch_secret DATABASE_URL_REMOTE)}"
if [[ -z "${DATABASE_URL_REMOTE:-}" ]]; then
  DATABASE_URL_REMOTE="$(_fetch_secret DATABASE_URL)"
fi
if [[ -z "${DATABASE_URL_LOCAL:-}" && -z "${DATABASE_URL_REMOTE:-}" ]]; then _echo_err "DATABASE_URL (or *_LOCAL/*_REMOTE) must be set in Doppler"; exit 1; fi

_parse_dsn_component(){
  local dsn="$1"
  local component="$2"
  if [[ -z "$dsn" ]]; then
    return
  fi
  python - "$dsn" "$component" <<'PY'
import sys
from urllib.parse import urlparse

parsed = urlparse(sys.argv[1])
component = sys.argv[2]
if component == "host":
    print(parsed.hostname or "")
elif component == "port":
    if parsed.port is not None:
        print(parsed.port)
PY
}

_rebuild_dsn_with_host_port(){
  local dsn="$1"
  local host="$2"
  local port="$3"
  if [[ -z "$dsn" ]]; then
    return
  fi
  python - "$dsn" "$host" "$port" <<'PY'
import sys
from urllib.parse import urlparse

dsn, host, port = sys.argv[1:4]
parsed = urlparse(dsn)
userinfo = ""
netloc = parsed.netloc
if "@" in netloc:
    userinfo, _, netloc = netloc.rpartition("@")
    userinfo += "@"
if ":" in netloc:
    hostname, _, _ = netloc.partition(":")
else:
    hostname = netloc
if port:
    host_port = f"{host}:{port}"
else:
    host_port = host
new_netloc = f"{userinfo}{host_port}"
print(parsed._replace(netloc=new_netloc).geturl())
PY
}

if [[ -z "${REMOTE_DB_HOST:-}" ]]; then
  REMOTE_DB_HOST="$(_parse_dsn_component "$DATABASE_URL_REMOTE" host)"
fi
if [[ -z "${REMOTE_DB_HOST:-}" ]]; then REMOTE_DB_HOST="127.0.0.1"; fi
if [[ -z "${REMOTE_DB_PORT:-}" ]]; then
  REMOTE_DB_PORT="$(_parse_dsn_component "$DATABASE_URL_REMOTE" port)"
fi
if [[ -z "${REMOTE_DB_PORT:-}" ]]; then REMOTE_DB_PORT="5432"; fi

if [[ "${USE_SSH_TUNNEL}" == "1" && -z "${DATABASE_URL_LOCAL:-}" && -n "${DATABASE_URL_REMOTE:-}" ]]; then
  DATABASE_URL_LOCAL="$(_rebuild_dsn_with_host_port "$DATABASE_URL_REMOTE" "$LOCAL_DB_HOST" "$LOCAL_DB_PORT")"
fi

TUNNEL_ACTIVE=0
TUNNEL_PID=""
cleanup(){ if [[ -n "${TUNNEL_PID:-}" ]]; then kill "$TUNNEL_PID" >/dev/null 2>&1 || true; wait "$TUNNEL_PID" 2>/dev/null || true; fi; }
trap cleanup EXIT

if [[ "${USE_SSH_TUNNEL}" == "1" ]]; then
  if ! command -v ssh >/dev/null 2>&1; then _echo_err "ssh not found"; exit 1; fi
  if ! command -v nc >/dev/null 2>&1; then _echo_err "nc not found"; exit 1; fi
  if [[ -z "${SSH_TARGET:-}" ]]; then _echo_err "SSH_TARGET required for tunnel"; exit 1; fi
  SSH_CMD=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -N -L "${LOCAL_DB_HOST}:${LOCAL_DB_PORT}:${REMOTE_DB_HOST}:${REMOTE_DB_PORT}")
  if [[ -n "${SSH_IDENTITY_FILE:-}" && -f "${SSH_IDENTITY_FILE}" ]]; then SSH_CMD+=(-i "$SSH_IDENTITY_FILE"); fi
  if [[ -n "${SSH_EXTRA_OPTS:-}" ]]; then
    # shellcheck disable=SC2206 # Intentional word splitting for additional ssh(1) flags
    SSH_CMD+=(${SSH_EXTRA_OPTS})
  fi
  SSH_CMD+=("${SSH_TARGET}")
  "${SSH_CMD[@]}" &
  TUNNEL_PID=$!
  sleep 1
  if ! kill -0 "$TUNNEL_PID" >/dev/null 2>&1; then _echo_err "Failed to establish SSH tunnel"; exit 1; fi
  if ! nc -z "${LOCAL_DB_HOST}" "${LOCAL_DB_PORT}" >/dev/null 2>&1; then _echo_err "Tunnel health check failed on ${LOCAL_DB_HOST}:${LOCAL_DB_PORT}"; exit 1; fi
  TUNNEL_ACTIVE=1
fi

cd "$SCRIPT_DIR"
export REPDUEL_STRICT_DB_BOOTSTRAP="${REPDUEL_STRICT_DB_BOOTSTRAP:-1}"

RUN_CMD=(env)
if [[ -n "${DATABASE_URL_REMOTE:-}" ]]; then
  RUN_CMD+=("DATABASE_URL=${DATABASE_URL_REMOTE}")
  RUN_CMD+=("DATABASE_URL_REMOTE=${DATABASE_URL_REMOTE}")
fi
if [[ -n "${DATABASE_URL_LOCAL:-}" ]]; then
  RUN_CMD+=("DATABASE_URL_INTERNAL=${DATABASE_URL_LOCAL}")
  RUN_CMD+=("DATABASE_URL_LOCAL=${DATABASE_URL_LOCAL}")
fi
if [[ -z "${DATABASE_URL_REMOTE:-}" && -n "${DATABASE_URL_LOCAL:-}" ]]; then
  RUN_CMD+=("DATABASE_URL=${DATABASE_URL_LOCAL}")
fi
RUN_CMD+=(uvicorn app.main:app --reload --host 127.0.0.1 --port 8000)

doppler run --project repduel --config dev_backend -- "${RUN_CMD[@]}"
