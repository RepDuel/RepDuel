#!/bin/bash
set -euo pipefail

# Paths
DEPLOY_DIR="/home/deploy/repduel"
BACKEND_DIR="$DEPLOY_DIR/backend"
SYSTEMD_SERVICE="repduel-backend"
CADDY_CONFIG="/etc/caddy/Caddyfile"

echo "➡️ Pulling latest code..."
cd "$DEPLOY_DIR"
git pull origin main

echo "➡️ Updating Python dependencies..."
cd "$BACKEND_DIR"
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

echo "➡️ Restarting backend service..."
sudo systemctl restart "$SYSTEMD_SERVICE"
sudo systemctl status "$SYSTEMD_SERVICE" --no-pager

echo "➡️ Validating Caddyfile..."
sudo caddy validate --config "$CADDY_CONFIG"

echo "➡️ Reloading Caddy..."
sudo caddy reload --config "$CADDY_CONFIG"

echo "➡️ Performing health check..."
if curl -fsS http://127.0.0.1:9999/health >/dev/null; then
    echo "✅ Backend healthy"
else
    echo "❌ Backend down"
    exit 1
fi

echo "🎉 Redeploy complete!"
