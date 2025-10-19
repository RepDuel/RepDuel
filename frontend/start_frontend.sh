#!/usr/bin/env bash
set -euo pipefail
echo "--- Starting RepDuel Frontend (dev) ---"
cd "$(dirname "$0")"
if ! command -v doppler >/dev/null 2>&1; then echo "doppler CLI not found"; exit 1; fi
if ! doppler --version >/dev/null 2>&1; then echo "doppler CLI not working"; exit 1; fi
if [[ -z "${DOPPLER_TOKEN:-}" ]]; then if ! doppler whoami >/dev/null 2>&1; then echo "Not logged into Doppler"; exit 1; fi; fi
if ! command -v flutter >/dev/null 2>&1; then echo "flutter not found"; exit 1; fi
get_secret() {
  local name="$1"
  local default_value="$2"
  local current_value="${!name:-}"

  if [[ -z "${current_value}" ]]; then
    current_value="$(doppler secrets get "${name}" --project repduel --config dev_frontend --plain 2>/dev/null || echo "${default_value}")"
  fi

  printf -v "${name}" '%s' "${current_value}"
}

get_secret BACKEND_URL "http://127.0.0.1:8000"
get_secret PUBLIC_BASE_URL "http://localhost:5000"
get_secret MERCHANT_DISPLAY_NAME "RepDuel"
get_secret REVENUE_CAT_APPLE_KEY ""
get_secret STRIPE_CANCEL_URL ""
get_secret STRIPE_PREMIUM_PLAN_ID ""
get_secret STRIPE_PUBLISHABLE_KEY ""
get_secret STRIPE_SUCCESS_URL ""
get_secret PAYMENTS_ENABLED "false"
doppler run --project repduel --config dev_frontend -- \
  flutter run -d chrome --web-port=5000 \
  --dart-define=BACKEND_URL="${BACKEND_URL}" \
  --dart-define=PUBLIC_BASE_URL="${PUBLIC_BASE_URL}" \
  --dart-define=MERCHANT_DISPLAY_NAME="${MERCHANT_DISPLAY_NAME}" \
  --dart-define=REVENUE_CAT_APPLE_KEY="${REVENUE_CAT_APPLE_KEY}" \
  --dart-define=STRIPE_CANCEL_URL="${STRIPE_CANCEL_URL}" \
  --dart-define=STRIPE_PREMIUM_PLAN_ID="${STRIPE_PREMIUM_PLAN_ID}" \
  --dart-define=STRIPE_PUBLISHABLE_KEY="${STRIPE_PUBLISHABLE_KEY}" \
  --dart-define=STRIPE_SUCCESS_URL="${STRIPE_SUCCESS_URL}" \
  --dart-define=PAYMENTS_ENABLED="${PAYMENTS_ENABLED}"
