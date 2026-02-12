#!/usr/bin/env bash
set -euo pipefail

# Billington — unified local development script
# Starts backend (Docker), web viewer (Next.js), and mobile app (Flutter/iOS Simulator)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_LOG="/tmp/billington-web.log"
WEB_PID=""

cleanup() {
  echo ""
  echo -e "${CYAN}Shutting down...${NC}"
  if [ -n "$WEB_PID" ] && kill -0 "$WEB_PID" 2>/dev/null; then
    kill "$WEB_PID" 2>/dev/null || true
    echo -e "${GREEN}Stopped Next.js dev server${NC}"
  fi
  echo -e "${YELLOW}Stopping Docker services...${NC}"
  docker-compose -f "$ROOT_DIR/backend/docker-compose.yml" down
  echo -e "${GREEN}Done.${NC}"
}

trap cleanup EXIT INT TERM

# ── Prerequisites ────────────────────────────────────────────────
echo -e "${CYAN}Checking prerequisites...${NC}"

missing=()
command -v docker    >/dev/null 2>&1 || missing+=("docker")
command -v node      >/dev/null 2>&1 || missing+=("node")
command -v flutter   >/dev/null 2>&1 || missing+=("flutter")

if [ ${#missing[@]} -gt 0 ]; then
  echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
  exit 1
fi
echo -e "${GREEN}All prerequisites found.${NC}"

# ── Environment files ────────────────────────────────────────────
if [ ! -f "$ROOT_DIR/backend/.env" ]; then
  echo -e "${YELLOW}Creating backend/.env from .env.example...${NC}"
  cp "$ROOT_DIR/backend/.env.example" "$ROOT_DIR/backend/.env"
fi

if [ ! -f "$ROOT_DIR/web-bill-viewer/.env.local" ]; then
  echo -e "${YELLOW}Creating web-bill-viewer/.env.local...${NC}"
  echo "NEXT_PUBLIC_API_URL=http://localhost:8080" > "$ROOT_DIR/web-bill-viewer/.env.local"
fi

# ── Backend (Docker) ─────────────────────────────────────────────
echo -e "${CYAN}Starting backend services...${NC}"
docker-compose -f "$ROOT_DIR/backend/docker-compose.yml" up --build -d

echo -e "${YELLOW}Waiting for backend health check...${NC}"
elapsed=0
until curl -sf http://localhost:8080/health > /dev/null 2>&1; do
  sleep 1
  elapsed=$((elapsed + 1))
  if [ "$elapsed" -ge 30 ]; then
    echo -e "${RED}Backend failed to start within 30 seconds.${NC}"
    echo "Check logs: docker-compose -f backend/docker-compose.yml logs"
    exit 1
  fi
done
echo -e "${GREEN}Backend healthy (${elapsed}s).${NC}"

# ── Web Viewer (Next.js) ────────────────────────────────────────
echo -e "${CYAN}Starting Next.js dev server...${NC}"
cd "$ROOT_DIR/web-bill-viewer"
npm install --silent 2>/dev/null
npm run dev > "$WEB_LOG" 2>&1 &
WEB_PID=$!
cd "$ROOT_DIR"

# Wait briefly for Next.js to initialize
sleep 3
if kill -0 "$WEB_PID" 2>/dev/null; then
  echo -e "${GREEN}Next.js running (PID $WEB_PID, logs at $WEB_LOG).${NC}"
else
  echo -e "${RED}Next.js failed to start. Check $WEB_LOG${NC}"
  exit 1
fi

# ── iOS Simulator + Flutter ──────────────────────────────────────
echo -e "${CYAN}Launching iOS Simulator...${NC}"
if ! xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
  # Boot the first available iPhone simulator
  SIM_ID=$(xcrun simctl list devices available -j 2>/dev/null \
    | python3 -c "import sys,json; devs=[d for r in json.load(sys.stdin)['devices'].values() for d in r if 'iPhone' in d['name'] and d['isAvailable']]; print(devs[0]['udid'] if devs else '')")
  if [ -n "$SIM_ID" ]; then
    xcrun simctl boot "$SIM_ID" 2>/dev/null || true
    open -a Simulator
    sleep 5
  else
    echo -e "${RED}No available iPhone simulator found.${NC}"
    exit 1
  fi
fi

# Get the booted simulator device ID for Flutter
BOOTED_SIM=$(xcrun simctl list devices booted -j 2>/dev/null \
  | python3 -c "import sys,json; devs=[d for r in json.load(sys.stdin)['devices'].values() for d in r if d['state']=='Booted']; print(devs[0]['udid'] if devs else '')")
if [ -z "$BOOTED_SIM" ]; then
  echo -e "${RED}No booted simulator found.${NC}"
  exit 1
fi
echo -e "${GREEN}Simulator ready ($BOOTED_SIM).${NC}"

echo -e "${CYAN}Running Flutter app...${NC}"
echo -e "${YELLOW}──────────────────────────────────────${NC}"
echo -e "  Backend:  http://localhost:8080/health"
echo -e "  Web:      http://localhost:3100"
echo -e "  Web logs: $WEB_LOG"
echo -e "${YELLOW}──────────────────────────────────────${NC}"

cd "$ROOT_DIR/mobile/ios" && pod install --silent 2>/dev/null
cd "$ROOT_DIR/mobile" && flutter run -d "$BOOTED_SIM"
