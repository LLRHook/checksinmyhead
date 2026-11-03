#!/usr/bin/env bash
set -euo pipefail

# One local entrypoint. Acquisition is explicit; runtime owns only what it starts.
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
STAGE=arguments
trap 'rc=$?; if [ "$rc" -ne 0 ]; then echo "Failed stage: $STAGE (exit $rc)" >&2; fi' EXIT
SETUP=false
MOBILE=true
for arg in "$@"; do
  case "$arg" in
    setup) SETUP=true ;;
    --no-mobile) MOBILE=false ;;
    *) echo "Usage: ./dev.sh [setup] [--no-mobile]" >&2; exit 2 ;;
  esac
done

fail() { echo "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing $1; install the documented toolchain, then run ./dev.sh setup."; }
compose() { docker compose -f "$ROOT_DIR/backend/docker-compose.yml" "$@"; }

STAGE=prerequisites
READY_TIMEOUT=${BILLINGTON_READY_TIMEOUT:-90}
[[ "$READY_TIMEOUT" =~ ^[1-9][0-9]*$ ]] && [ "$READY_TIMEOUT" -le 180 ] || fail 'BILLINGTON_READY_TIMEOUT must be 1–180 seconds.'
for tool in docker node npm python3 curl lsof; do need "$tool"; done
docker compose version >/dev/null || fail 'Docker Compose subcommand required: docker compose version'
# Read maintained pins, never dotenv. Existing environment files belong to the user.
NODE_MAJOR=$(cat web-bill-viewer/.node-version)
[[ "$(node --version)" == v"$NODE_MAJOR".* ]] || fail "Use Node $NODE_MAJOR (web-bill-viewer/.node-version)."
[[ "$(npm --version)" == 11.* ]] || fail 'Use npm 11 (web-bill-viewer/README.md).'
if $MOBILE; then
  for tool in flutter pod xcrun; do need "$tool"; done
  FLUTTER_PIN=$(python3 -c 'import re; print(re.search(r"FLUTTER_VERSION: ([\d.]+)", open(".github/workflows/ci.yml").read())[1])')
  FLUTTER_VERSION=$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')
  [[ "$FLUTTER_VERSION" == "$FLUTTER_PIN" ]] || fail "Use Flutter $FLUTTER_PIN (.github/workflows/ci.yml)."
  POD_PIN=$(sed -n 's/^COCOAPODS: //p' mobile/ios/Podfile.lock)
  [[ "$(pod --version)" == "$POD_PIN" ]] || fail "Use CocoaPods $POD_PIN (mobile/ios/Podfile.lock)."
fi

if $SETUP; then
  # No trap/service shutdown here: setup never owns running services.
  STAGE='web locked setup (npm ci)'
  if [ ! -f backend/.env ]; then cp backend/.env.example backend/.env; fi
  if [ ! -f web-bill-viewer/.env.local ]; then
    printf '%s\n' 'NEXT_PUBLIC_API_URL=http://localhost:8080' > web-bill-viewer/.env.local
  fi
  (cd web-bill-viewer && npm ci)
  if $MOBILE; then
    STAGE='Flutter locked setup'
    (cd mobile && flutter pub get --enforce-lockfile)
    STAGE='CocoaPods locked setup'
    (cd mobile/ios && pod install --deployment)
  fi
  echo 'Setup complete. Run ./dev.sh with the same --no-mobile choice if used.'
  exit 0
fi

STAGE='prepared dependencies'
[ -f backend/.env ] && [ -f web-bill-viewer/.env.local ] || fail 'Missing local environment file. Run ./dev.sh setup (or setup --no-mobile).'
[ -x web-bill-viewer/node_modules/.bin/next ] || fail 'Missing web dependencies. Run ./dev.sh setup (or setup --no-mobile).'
if $MOBILE; then
  [ -f mobile/.dart_tool/package_config.json ] &&
    cmp -s mobile/ios/Podfile.lock mobile/ios/Pods/Manifest.lock || fail 'Missing/stale mobile dependencies. Run ./dev.sh setup.'
  STAGE='simulator selection'
  # Only a named available iOS device, or the sole already-booted iOS device.
  SIM_ID=$(xcrun simctl list devices available -j | python3 -c '
import json,os,sys
all_devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if ".iOS-" in runtime for d in ds if d.get("isAvailable")]
selected = os.environ.get("BILLINGTON_SIMULATOR_ID")
devices = [d for d in all_devices if d["udid"] == selected] if selected else [d for d in all_devices if d["state"] == "Booted"]
if len(devices) != 1:
    sys.exit("Select one available iOS simulator with BILLINGTON_SIMULATOR_ID; otherwise exactly one must already be booted.")
print(devices[0]["udid"] + " " + devices[0]["state"])
')
  SIM_STATE=${SIM_ID#* }
  SIM_ID=${SIM_ID%% *}
fi
STAGE='Compose validation'
compose config --quiet
# A conflict is not permission to kill its owner. A running API is checked below.
if lsof -nP -iTCP:3100 -sTCP:LISTEN >/dev/null 2>&1; then fail 'Port 3100 is occupied. Stop its owner yourself before running ./dev.sh.'; fi

docker info >/dev/null
RUN_DIR=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/billington-dev.XXXXXXXX")
WEB_LOG="$RUN_DIR/web.log"
WEB_PID=''
MOBILE_PID=''
PENDING_SERVICE=''
OWNED_CONTAINERS=()
CLEANED=false
cleanup() {
  local rc=$1 pid id deadline
  $CLEANED && return
  CLEANED=true
  trap - EXIT
  trap '' INT TERM
  set +e
  if [ -n "$PENDING_SERVICE" ]; then remember_pending; fi
  for pid in "$MOBILE_PID" "$WEB_PID"; do
    [ -n "$pid" ] || continue
    # Job control creates a private group for each background command, including
    # npm -> shell -> Next descendants. Never search by port/name or signal all Node.
    kill -TERM -- "-$pid" 2>/dev/null
  done
  deadline=$((SECONDS + 5))
  for pid in "$MOBILE_PID" "$WEB_PID"; do
    [ -n "$pid" ] || continue
    while kill -0 -- "-$pid" 2>/dev/null && [ "$SECONDS" -lt "$deadline" ]; do sleep 0.1; done
    kill -KILL -- "-$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  # Reverse startup order; stopped containers and every data volume are retained.
  if [ "${#OWNED_CONTAINERS[@]}" -gt 0 ]; then
    for ((i=${#OWNED_CONTAINERS[@]}-1; i>=0; i--)); do
      id=${OWNED_CONTAINERS[i]}
      docker stop --time 5 "$id" >/dev/null || echo "Could not stop owned container $id; inspect it manually." >&2
    done
  fi
  if [ "$rc" -ne 0 ]; then echo "Failed stage: $STAGE (exit $rc). Web diagnostics: $WEB_LOG" >&2; fi
  exit "$rc"
}
trap 'cleanup "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Available in macOS Bash 3.2 as well as maintained Bash. Each async job has its own PGID.
set -m

container_id() {
  local ids
  ids=$(compose ps --all --quiet "$1")
  [[ "$ids" != *$'\n'* ]] || fail "Multiple $1 containers; resolve the Compose project before startup."
  printf '%s' "$ids"
}
remember_pending() {
  local id existing
  id=$(container_id "$PENDING_SERVICE") || { echo 'Could not identify partially started service; inspect Compose ps.' >&2; return; }
  if [ -n "$id" ]; then
    if [ "${#OWNED_CONTAINERS[@]}" -gt 0 ]; then
      for existing in "${OWNED_CONTAINERS[@]}"; do [ "$existing" != "$id" ] || return; done
    fi
    OWNED_CONTAINERS+=("$id")
  fi
}
container_running() { [ "$(docker inspect --format '{{.State.Running}}' "$1")" = true ]; }
start_service() {
  local service=$1 before rc=0
  STAGE="starting $service"
  before=$(container_id "$service")
  if [ -n "$before" ] && container_running "$before"; then
    echo "Preserving running $service ($before)."
    return
  fi
  if [ "$service" = bill-service ] && lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
    fail 'Port 8080 is occupied. Stop its owner yourself before running ./dev.sh.'
  fi
  # Reuse stopped containers without replacing their environment/configuration.
  # Record partial creation even when up/start fails, so EXIT can stop owned work.
  if [ -n "$before" ]; then
    OWNED_CONTAINERS+=("$before")
    compose start "$service" || rc=$?
  else
    PENDING_SERVICE=$service
    compose up --build --no-deps -d "$service" || rc=$?
    remember_pending
    PENDING_SERVICE=''
  fi
  [ "$rc" -eq 0 ] || return "$rc"
}
wait_service() {
  local service=$1 id deadline=$((SECONDS + READY_TIMEOUT)) state
  STAGE="$service readiness"
  id=$(container_id "$service")
  [ -n "$id" ] || fail "No $service container was created. Run: docker compose -f backend/docker-compose.yml ps"
  while [ "$SECONDS" -lt "$deadline" ]; do
    state=$(docker inspect --format '{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$id")
    case "$state" in
      'true healthy') return ;;
      'true starting') sleep 1 ;;
      *) fail "$service is not healthy ($state). Inspect: docker compose -f backend/docker-compose.yml logs --tail 50 $service" ;;
    esac
  done
  fail "$service readiness timed out after ${READY_TIMEOUT}s. Inspect: docker compose -f backend/docker-compose.yml logs --tail 50 $service"
}
start_service postgres
wait_service postgres
start_service bill-service
wait_service bill-service
STAGE='API loopback readiness'
curl --fail --silent --show-error --connect-timeout 1 --max-time 3 http://localhost:8080/health >/dev/null

STAGE='Next.js startup'
(cd web-bill-viewer && exec npm run dev) >"$WEB_LOG" 2>&1 &
WEB_PID=$!
deadline=$((SECONDS + READY_TIMEOUT))
until curl --fail --silent --connect-timeout 1 --max-time 2 http://localhost:3100/ >/dev/null 2>&1; do
  if ! kill -0 "$WEB_PID" 2>/dev/null; then
    rc=0; wait "$WEB_PID" || rc=$?
    tail -n 40 "$WEB_LOG" >&2
    [ "$rc" -ne 0 ] || rc=1
    exit "$rc"
  fi
  [ "$SECONDS" -lt "$deadline" ] || { tail -n 40 "$WEB_LOG" >&2; fail "Next.js readiness timed out after ${READY_TIMEOUT}s."; }
  sleep 1
done
echo "Ready: API http://localhost:8080/health; web http://localhost:3100; private logs $WEB_LOG"

if $MOBILE; then
  STAGE='simulator readiness'
  if [ "$SIM_STATE" != Booted ]; then xcrun simctl boot "$SIM_ID"; fi
  deadline=$((SECONDS + READY_TIMEOUT))
  until xcrun simctl getenv "$SIM_ID" HOME >/dev/null 2>&1; do
    [ "$SECONDS" -lt "$deadline" ] || fail "Selected simulator readiness timed out after ${READY_TIMEOUT}s."
    sleep 1
  done
  # Flutter can request pod install even with --no-pub. Fail that request visibly;
  # all acquisition belongs to setup --deployment, including changed plugin state.
  mkdir "$RUN_DIR/bin"
  export BILLINGTON_DEV_POD
  BILLINGTON_DEV_POD=$(command -v pod)
  cat > "$RUN_DIR/bin/pod" <<'POD'
#!/usr/bin/env bash
if [ "$*" = --version ]; then exec "$BILLINGTON_DEV_POD" --version; fi
echo 'CocoaPods acquisition requested during startup. Run ./dev.sh setup first.' >&2
exit 1
POD
  chmod 700 "$RUN_DIR/bin/pod"
  STAGE='Flutter run'
  (cd mobile && PATH="$RUN_DIR/bin:$PATH" exec flutter run --no-pub -d "$SIM_ID") &
  MOBILE_PID=$!
  # Give interactive Flutter the terminal for hot reload/quit. In non-TTY runs,
  # monitor both owned jobs below instead.
  if [ -t 0 ]; then
    STAGE='Flutter run'
    fg %+
    exit 0
  fi
fi
STAGE='running (Ctrl-C to stop owned services)'
while kill -0 "$WEB_PID" 2>/dev/null; do
  if [ -n "$MOBILE_PID" ] && ! kill -0 "$MOBILE_PID" 2>/dev/null; then wait "$MOBILE_PID"; exit 0; fi
  sleep 1
done
rc=0; wait "$WEB_PID" || rc=$?
tail -n 40 "$WEB_LOG" >&2
[ "$rc" -ne 0 ] || rc=1
exit "$rc"
