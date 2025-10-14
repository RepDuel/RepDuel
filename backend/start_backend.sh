#!/usr/bin/env bash
set -euo pipefail

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

DATABASE_URL_PUBLIC="${DATABASE_URL:-$(_fetch_secret DATABASE_URL)}"
DATABASE_URL_REMOTE="${DATABASE_URL_REMOTE:-$(_fetch_secret DATABASE_URL_REMOTE)}"
DATABASE_URL_INTERNAL="${DATABASE_URL_INTERNAL:-$(_fetch_secret DATABASE_URL_INTERNAL)}"

if [[ -z "${DATABASE_URL_PUBLIC:-}" && -z "${DATABASE_URL_REMOTE:-}" ]]; then
  _echo_err "DATABASE_URL or DATABASE_URL_REMOTE must be set in Doppler"
  exit 1
fi

if [[ -z "${DATABASE_URL_PUBLIC:-}" ]]; then
  DATABASE_URL_PUBLIC="$DATABASE_URL_REMOTE"
fi

if [[ -z "${DATABASE_URL_REMOTE:-}" ]]; then
  DATABASE_URL_REMOTE="$DATABASE_URL_PUBLIC"
fi

if [[ -z "${DATABASE_URL_INTERNAL:-}" ]]; then
  DATABASE_URL_INTERNAL="$DATABASE_URL_PUBLIC"
fi

cd "$SCRIPT_DIR"
export REPDUEL_STRICT_DB_BOOTSTRAP="${REPDUEL_STRICT_DB_BOOTSTRAP:-1}"

RUN_CMD=(env)
RUN_CMD+=("DATABASE_URL=${DATABASE_URL_PUBLIC}")
RUN_CMD+=("DATABASE_URL_REMOTE=${DATABASE_URL_REMOTE}")
RUN_CMD+=("DATABASE_URL_INTERNAL=${DATABASE_URL_INTERNAL}")
RUN_CMD+=("DATABASE_URL_LOCAL=${DATABASE_URL_INTERNAL}")
RUN_CMD+=(uvicorn app.main:app --reload --host 127.0.0.1 --port 8000)

doppler run --project repduel --config dev_backend -- "${RUN_CMD[@]}"
