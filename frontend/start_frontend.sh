#!/usr/bin/env bash
set -euo pipefail

echo "--- Starting RepDuel Frontend (dev) ---"

# run from the script’s directory
cd "$(dirname "$0")"

doppler run --project repduel --config dev_frontend -- \
  flutter run -d chrome --web-port=5000 \
    --dart-define=BACKEND_URL=http://127.0.0.1:8000
