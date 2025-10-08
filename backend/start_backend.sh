#!/bin/bash
set -euo pipefail

echo "--- Starting RepDuel Backend (Doppler) ---"

PROJECT="${PROJECT:-repduel}"
CONFIG="${CONFIG:-dev_backend}"

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

if [[ ! -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
  echo "Virtual env not found at $PROJECT_ROOT/.venv. Create it and install deps."; exit 1
fi
source "$PROJECT_ROOT/.venv/bin/activate"

cd "$SCRIPT_DIR"

doppler run --project "$PROJECT" --config "$CONFIG" -- \
  uvicorn app.main:app --reload --host 127.0.0.1 --port 8000 --log-level error
