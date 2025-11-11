#!/bin/bash
set -euo pipefail

echo "🔧 RepDuel Backend Troubleshooting Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verify PostgreSQL is on port 9991
echo "📍 Step 1: Checking PostgreSQL port configuration..."
PG_PORT=$(sudo cat /etc/postgresql/*/main/postgresql.conf | grep -E "^port" | awk '{print $3}' || echo "not_found")
if [[ "$PG_PORT" == "9991" ]]; then
    echo -e "${GREEN}✓ PostgreSQL is configured for port 9991${NC}"
else
    echo -e "${RED}✗ PostgreSQL port is: $PG_PORT (expected 9991)${NC}"
    echo "  Fixing configuration..."
    sudo sed -i "s/^port = .*/port = 9991/" /etc/postgresql/*/main/postgresql.conf
    echo "  Restarting PostgreSQL..."
    sudo systemctl restart postgresql
    sleep 2
fi

# Verify PostgreSQL is actually listening on 9991
echo "  Checking if PostgreSQL is listening on 9991..."
if sudo ss -tulnp | grep -q ":9991"; then
    echo -e "${GREEN}✓ PostgreSQL is listening on port 9991${NC}"
else
    echo -e "${RED}✗ PostgreSQL is NOT listening on port 9991${NC}"
    echo "  Attempting to restart PostgreSQL..."
    sudo systemctl restart postgresql
    sleep 3
    if sudo ss -tulnp | grep -q ":9991"; then
        echo -e "${GREEN}✓ PostgreSQL is now listening on port 9991${NC}"
    else
        echo -e "${RED}✗ PostgreSQL failed to start on port 9991${NC}"
        sudo journalctl -u postgresql -n 20 --no-pager
        exit 1
    fi
fi
echo ""

# Step 2: Check backend database configuration
echo "📍 Step 2: Checking backend database configuration..."
cd /home/deploy/repduel/backend
if doppler secrets get DATABASE_URL --project repduel --config prd_backend --plain 2>/dev/null | grep -q ":9991"; then
    echo -e "${GREEN}✓ DATABASE_URL uses port 9991${NC}"
else
    echo -e "${YELLOW}⚠ DATABASE_URL may not be using port 9991${NC}"
    echo "  Current DATABASE_URL (masked):"
    doppler secrets get DATABASE_URL --project repduel --config prd_backend --plain 2>/dev/null | sed 's/:[^@]*@/:****@/' || echo "  Could not retrieve DATABASE_URL"
fi
echo ""

# Step 3: Stop conflicting backend processes
echo "📍 Step 3: Stopping any conflicting backend processes..."
if sudo systemctl is-active --quiet repduel-backend; then
    echo "  Stopping repduel-backend service..."
    sudo systemctl stop repduel-backend
    sleep 2
fi

# Kill any leftover uvicorn processes
LEFTOVER=$(pgrep -f uvicorn 2>/dev/null | wc -l || echo "0")
if [[ $LEFTOVER -gt 0 ]]; then
    echo "  Found $LEFTOVER leftover uvicorn processes, killing them..."
    sudo pkill -f uvicorn || true
    sleep 2
fi

# Check if port 8000 or 9999 are in use
for port in 8000 9999; do
    if sudo ss -tulnp | grep -q ":$port.*uvicorn"; then
        echo -e "${RED}✗ Port $port is still in use by uvicorn${NC}"
        PID=$(sudo ss -tulnp | grep ":$port.*uvicorn" | awk '{print $7}' | cut -d',' -f2 | cut -d'=' -f2)
        echo "  Killing process $PID..."
        sudo kill -9 $PID || true
        sleep 1
    fi
done
echo -e "${GREEN}✓ No conflicting backend processes found${NC}"
echo ""

# Step 4: Validate Caddy configuration
echo "📍 Step 4: Validating Caddy configuration..."
if sudo caddy validate --config /etc/caddy/Caddyfile; then
    echo -e "${GREEN}✓ Caddyfile is valid${NC}"
else
    echo -e "${RED}✗ Caddyfile validation failed${NC}"
    exit 1
fi

# Check Caddy service status
if sudo systemctl is-active --quiet caddy; then
    echo -e "${GREEN}✓ Caddy is running${NC}"
else
    echo -e "${YELLOW}⚠ Caddy is not running, starting it...${NC}"
    sudo systemctl start caddy
    sleep 2
fi
echo ""

# Step 5: Start the backend
echo "📍 Step 5: Starting the backend..."
sudo systemctl start repduel-backend
sleep 3

# Check if service started successfully
if sudo systemctl is-active --quiet repduel-backend; then
    echo -e "${GREEN}✓ Backend service started${NC}"
    sudo systemctl status repduel-backend --no-pager | head -20
else
    echo -e "${RED}✗ Backend service failed to start${NC}"
    echo "  Recent logs:"
    sudo journalctl -u repduel-backend -n 30 --no-pager
    exit 1
fi
echo ""

# Wait for backend to fully start
echo "  Waiting 5 seconds for backend to fully initialize..."
sleep 5

# Step 6: Test the backend
echo "📍 Step 6: Testing the backend..."

# Test directly on localhost
echo "  Testing direct backend connection (localhost:9999)..."
if curl -f -s -o /dev/null -w "%{http_code}" http://localhost:9999/health | grep -q "200\|307"; then
    echo -e "${GREEN}✓ Backend responds on localhost:9999${NC}"
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9999/health || echo "000")
    echo -e "${RED}✗ Backend not responding on localhost:9999 (HTTP $HTTP_CODE)${NC}"
    echo "  Backend logs:"
    sudo journalctl -u repduel-backend -n 20 --no-pager
fi

# Test through Caddy
echo "  Testing through Caddy (api.repduel.com)..."
if curl -f -s -o /dev/null -w "%{http_code}" https://api.repduel.com/health | grep -q "200\|307"; then
    echo -e "${GREEN}✓ Backend accessible through Caddy${NC}"
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://api.repduel.com/health || echo "000")
    echo -e "${RED}✗ Backend not accessible through Caddy (HTTP $HTTP_CODE)${NC}"
    echo "  Caddy logs:"
    sudo journalctl -u caddy -n 20 --no-pager
fi
echo ""

# Step 7: Final checks
echo "📍 Step 7: Final checks and diagnostics..."
echo ""
echo "🔍 Port bindings:"
sudo ss -tulnp | grep -E ":(9991|9999|8000|80|443)" || echo "  No relevant ports found"
echo ""

echo "🔍 Recent backend logs (last 15 lines):"
sudo journalctl -u repduel-backend -n 15 --no-pager
echo ""

echo "🔍 Recent Caddy logs (last 10 lines):"
sudo journalctl -u caddy -n 10 --no-pager
echo ""

echo "=========================================="
echo "✅ Troubleshooting complete!"
echo ""
echo "Quick verification commands:"
echo "  • Backend health: curl -I http://localhost:9999/health"
echo "  • Through Caddy:  curl -I https://api.repduel.com/health"
echo "  • Backend logs:   sudo journalctl -u repduel-backend -f"
echo "  • Caddy logs:     sudo journalctl -u caddy -f"
