#!/usr/bin/env bash
set -euo pipefail
echo "--- Starting RepDuel Frontend (dev) ---"
cd "$(dirname "$0")"
if ! command -v doppler >/dev/null 2>&1; then echo "doppler CLI not found"; exit 1; fi
if ! doppler --version >/dev/null 2>&1; then echo "doppler CLI not working"; exit 1; fi
if [[ -z "${DOPPLER_TOKEN:-}" ]]; then if ! doppler whoami >/dev/null 2>&1; then echo "Not logged into Doppler"; exit 1; fi; fi
if ! command -v flutter >/dev/null 2>&1; then echo "flutter not found"; exit 1; fi
BACKEND_URL="${BACKEND_URL:-$(doppler secrets get BACKEND_URL --project repduel --config dev_frontend --plain 2>/dev/null || echo http://127.0.0.1:8000)}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-$(doppler secrets get PUBLIC_BASE_URL --project repduel --config dev_frontend --plain 2>/dev/null || echo http://localhost:5000)}"
doppler run --project repduel --config dev_frontend -- \
flutter run -d chrome --web-port=5000 \
  --dart-define=BACKEND_URL="${BACKEND_URL}" \
  --dart-define=PUBLIC_BASE_URL="${PUBLIC_BASE_URL}"
