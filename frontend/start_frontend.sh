#!/usr/bin/env bash
set -euo pipefail

echo "--- Starting RepDuel Frontend (Doppler) ---"

# run from the script’s directory
cd "$(dirname "$0")"

doppler run --project repduel --config dev_frontend -- \
  flutter run -d chrome --web-port=5000
