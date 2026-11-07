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
READY_TIMEOUT=${BILLINGTON_READY_TIMEOUT:-90}
[[ "$READY_TIMEOUT" =~ ^[1-9][0-9]*$ ]] && [ "$READY_TIMEOUT" -le 180 ] || fail 'BILLINGTON_READY_TIMEOUT must be 1–180 seconds.'
need python3
RUNTIME="$ROOT_DIR/scripts/dev_runtime.py"
RUN_DIR=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/billington-dev.XXXXXXXX")
WEB_LOG="$RUN_DIR/web.log"
DEADLINE_FILE="$RUN_DIR/deadline"
TTY_FILE="$RUN_DIR/terminal.json"
WEB_PID=''
MOBILE_PID=''
PROBE_PID=''
PENDING_SERVICE=''
OWNED_CONTAINERS=()
CLEANED=false
CAPTURE_SEQUENCE=0

# Wait is a Bash builtin and is interruptible by the driver's signal traps. Do
# not hide this ownership assignment in a command-substitution subshell.
run_command() {
  local budget=$1 directory=$2 rc=0
  shift 2
  python3 "$RUNTIME" run "$budget" "$directory" "$@" &
  PROBE_PID=$!
  wait "$PROBE_PID" 2>/dev/null || rc=$?
  PROBE_PID=''
  return "$rc"
}
begin_stage() {
  STAGE=$1
  python3 "$RUNTIME" deadline "$DEADLINE_FILE" "$READY_TIMEOUT"
}
probe_capture() {
  local capture_target=$1 capture_value rc=0
  shift
  CAPTURE_SEQUENCE=$((CAPTURE_SEQUENCE + 1))
  LAST_PROBE_FILE="$RUN_DIR/probe-$CAPTURE_SEQUENCE"
  run_command "$DEADLINE_FILE" "$ROOT_DIR" "$@" >"$LAST_PROBE_FILE" || rc=$?
  capture_value=$(<"$LAST_PROBE_FILE")
  printf -v "$capture_target" '%s' "$capture_value"
  return "$rc"
}
compose() { run_command "$DEADLINE_FILE" "$ROOT_DIR" docker compose -f "$ROOT_DIR/backend/docker-compose.yml" "$@"; }
container_id() {
  local container_ids
  probe_capture container_ids docker compose -f "$ROOT_DIR/backend/docker-compose.yml" ps --all --quiet "$1" || return "$?"
  [[ "$container_ids" != *$'\n'* ]] || fail "Multiple $1 containers; resolve the Compose project before startup."
  printf -v "$2" '%s' "$container_ids"
}
remember_pending() {
  local pending_id existing rc
  container_id "$PENDING_SERVICE" pending_id || { rc=$?; echo 'Could not identify partially started service; inspect Compose ps.' >&2; return "$rc"; }
  [ -n "$pending_id" ] || { echo 'Could not identify partially started service; inspect Compose ps.' >&2; return 1; }
  if [ "${#OWNED_CONTAINERS[@]}" -gt 0 ]; then
    for existing in "${OWNED_CONTAINERS[@]}"; do [ "$existing" != "$pending_id" ] || return 0; done
  fi
  OWNED_CONTAINERS+=("$pending_id")
}
cleanup() {
  local rc=$1 pid id deadline
  $CLEANED && return
  CLEANED=true
  trap - EXIT
  trap '' INT TERM
  set +e
  # A probe helper may not yet have established its group. Its exact PID is
  # always owned; its handler terminates/reaps the command's separate group.
  if [ -n "$PROBE_PID" ]; then
    kill -TERM "$PROBE_PID" 2>/dev/null
    kill -TERM -- "-$PROBE_PID" 2>/dev/null
    deadline=$((SECONDS + 3))
    while kill -0 "$PROBE_PID" 2>/dev/null && [ "$SECONDS" -lt "$deadline" ]; do sleep .1; done
    kill -KILL -- "-$PROBE_PID" 2>/dev/null
    kill -KILL "$PROBE_PID" 2>/dev/null
    wait "$PROBE_PID" 2>/dev/null
    PROBE_PID=''
  fi
  if [ -n "$PENDING_SERVICE" ]; then
    python3 "$RUNTIME" deadline "$DEADLINE_FILE" 3
    remember_pending || echo "Pending $PENDING_SERVICE ownership remains unknown; inspect Compose ps before manual cleanup." >&2
  fi
  for pid in "$MOBILE_PID" "$WEB_PID"; do
    [ -n "$pid" ] || continue
    kill -TERM -- "-$pid" 2>/dev/null
  done
  # These are development processes, not the durable database. Give them two
  # seconds to exit before reaping their groups; Compose has its own stop budget.
  deadline=$((SECONDS + 2))
  for pid in "$MOBILE_PID" "$WEB_PID"; do
    [ -n "$pid" ] || continue
    while kill -0 -- "-$pid" 2>/dev/null && [ "$SECONDS" -lt "$deadline" ]; do sleep .1; done
    kill -KILL -- "-$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  if [ -f "$TTY_FILE" ]; then
    python3 "$RUNTIME" tty-restore "$TTY_FILE" || echo 'Could not restore terminal settings; run stty sane.' >&2
  fi
  if [ "${#OWNED_CONTAINERS[@]}" -gt 0 ]; then
    for ((i=${#OWNED_CONTAINERS[@]}-1; i>=0; i--)); do
      id=${OWNED_CONTAINERS[i]}
      python3 "$RUNTIME" deadline "$DEADLINE_FILE" 7
      run_command "$DEADLINE_FILE" "$ROOT_DIR" docker stop --time 5 "$id" >/dev/null || echo "Could not stop owned container $id; inspect it manually." >&2
    done
  fi
  if [ "$rc" -ne 0 ]; then echo "Failed stage: $STAGE (exit $rc). Web diagnostics: $WEB_LOG" >&2; fi
  exit "$rc"
}
trap 'cleanup "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
set -m

begin_stage prerequisites
for tool in docker node npm curl lsof; do need "$tool"; done
run_command "$DEADLINE_FILE" "$ROOT_DIR" docker compose version >/dev/null || fail 'Docker Compose subcommand required: docker compose version'
NODE_MAJOR=$(cat web-bill-viewer/.node-version)
begin_stage 'Node version'
probe_capture NODE_VERSION node --version
[[ "$NODE_VERSION" == v"$NODE_MAJOR".* ]] || fail "Use Node $NODE_MAJOR (web-bill-viewer/.node-version)."
begin_stage 'npm version'
probe_capture NPM_VERSION npm --version
[[ "$NPM_VERSION" == 11.* ]] || fail 'Use npm 11 (web-bill-viewer/README.md).'
if $MOBILE; then
  for tool in flutter pod xcrun; do need "$tool"; done
  FLUTTER_PIN=$(python3 - <<'PY'
import re
from pathlib import Path
versions = re.findall(r"(?m)^\s*flutter-version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$", Path(".github/workflows/checks.yml").read_text())
if len(versions) != 1:
    raise SystemExit("Expected one literal Flutter SDK pin in .github/workflows/checks.yml.")
print(versions[0])
PY
  )
  begin_stage 'Flutter version'
  probe_capture FLUTTER_JSON flutter --version --machine
  FLUTTER_VERSION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["frameworkVersion"])' "$LAST_PROBE_FILE")
  [[ "$FLUTTER_VERSION" == "$FLUTTER_PIN" ]] || fail "Use Flutter $FLUTTER_PIN (.github/workflows/checks.yml)."
  POD_PIN=$(sed -n 's/^COCOAPODS: //p' mobile/ios/Podfile.lock)
  begin_stage 'CocoaPods version'
  probe_capture POD_VERSION pod --version
  [[ "$POD_VERSION" == "$POD_PIN" ]] || fail "Use CocoaPods $POD_PIN (mobile/ios/Podfile.lock)."
fi

if $SETUP; then
  # Acquisition may take longer than readiness; it remains owned/cancellable.
  STAGE='web locked setup (npm ci)'
  if [ ! -f backend/.env ]; then cp backend/.env.example backend/.env; fi
  if [ ! -f web-bill-viewer/.env.local ]; then printf '%s\n' 'NEXT_PUBLIC_API_URL=http://localhost:8080' > web-bill-viewer/.env.local; fi
  run_command - "$ROOT_DIR/web-bill-viewer" npm ci
  if $MOBILE; then
    STAGE='Flutter locked setup'
    run_command - "$ROOT_DIR/mobile" flutter pub get --enforce-lockfile
    STAGE='CocoaPods locked setup'
    run_command - "$ROOT_DIR/mobile/ios" pod install --deployment
  fi
  echo 'Setup complete. Run ./dev.sh with the same --no-mobile choice if used.'
  exit 0
fi

STAGE='prepared dependencies'
[ -f backend/.env ] && [ -f web-bill-viewer/.env.local ] || fail 'Missing local environment file. Run ./dev.sh setup (or setup --no-mobile).'
[ -x web-bill-viewer/node_modules/.bin/next ] || fail 'Missing web dependencies. Run ./dev.sh setup (or setup --no-mobile).'
if $MOBILE; then
  [ -f mobile/.dart_tool/package_config.json ] && cmp -s mobile/ios/Podfile.lock mobile/ios/Pods/Manifest.lock || fail 'Missing/stale mobile dependencies. Run ./dev.sh setup.'
  begin_stage 'simulator selection'
  probe_capture SIM_JSON xcrun simctl list devices available -j
  SIM_ID=$(python3 -c '
import json,os,sys
all_devices = [d for runtime, ds in json.load(open(sys.argv[1]))["devices"].items() if ".iOS-" in runtime for d in ds if d.get("isAvailable")]
selected = os.environ.get("BILLINGTON_SIMULATOR_ID")
devices = [d for d in all_devices if d["udid"] == selected] if selected else [d for d in all_devices if d["state"] == "Booted"]
if len(devices) != 1:
    sys.exit("Select one available iOS simulator with BILLINGTON_SIMULATOR_ID; otherwise exactly one must already be booted.")
print(devices[0]["udid"] + " " + devices[0]["state"])
' "$LAST_PROBE_FILE")
  SIM_STATE=${SIM_ID#* }
  SIM_ID=${SIM_ID%% *}
fi
begin_stage 'Compose validation'
compose config --quiet
if lsof -nP -iTCP:3100 -sTCP:LISTEN >/dev/null 2>&1; then fail 'Port 3100 is occupied. Stop its owner yourself before running ./dev.sh.'; fi
run_command "$DEADLINE_FILE" "$ROOT_DIR" docker info >/dev/null

start_service() {
  local service=$1 before running rc=0 capture_rc
  begin_stage "starting $service"
  container_id "$service" before || return "$?"
  if [ -n "$before" ]; then
    probe_capture running docker inspect --format '{{.State.Running}}' "$before" || return "$?"
    if [ "$running" = true ]; then echo "Preserving running $service ($before)."; return; fi
  fi
  if [ "$service" = bill-service ] && lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then fail 'Port 8080 is occupied. Stop its owner yourself before running ./dev.sh.'; fi
  # Build/start is separately cancellable; readiness gets its own stage budget.
  if [ -n "$before" ]; then
    OWNED_CONTAINERS+=("$before")
    run_command - "$ROOT_DIR" docker compose -f "$ROOT_DIR/backend/docker-compose.yml" start "$service" || rc=$?
  else
    PENDING_SERVICE=$service
    run_command - "$ROOT_DIR" docker compose -f "$ROOT_DIR/backend/docker-compose.yml" up --build --no-deps -d "$service" || rc=$?
    begin_stage "capturing $service ownership"
    if remember_pending; then PENDING_SERVICE=''; else
      capture_rc=$?
      [ "$rc" -ne 0 ] && return "$rc"
      return "$capture_rc"
    fi
  fi
  [ "$rc" -eq 0 ] || return "$rc"
}
wait_service() {
  local service=$1 id state rc
  begin_stage "$service readiness"
  container_id "$service" id || return "$?"
  [ -n "$id" ] || fail "No $service container was created. Run: docker compose -f backend/docker-compose.yml ps"
  while true; do
    if probe_capture state docker inspect --format '{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$id"; then :; else
      rc=$?
      [ "$rc" -ne 124 ] || fail "$service readiness timed out after ${READY_TIMEOUT}s."
      return "$rc"
    fi
    case "$state" in
      'true healthy') return ;;
      'true starting') sleep .1 ;;
      *) fail "$service is not healthy ($state). Inspect: docker compose -f backend/docker-compose.yml logs --tail 50 $service" ;;
    esac
  done
}
start_service postgres
wait_service postgres
start_service bill-service
wait_service bill-service
begin_stage 'API loopback readiness'
run_command "$DEADLINE_FILE" "$ROOT_DIR" curl --fail --silent --show-error --connect-timeout 1 --max-time 3 http://localhost:8080/health >/dev/null

begin_stage 'Next.js startup'
(cd web-bill-viewer && exec npm run dev) >"$WEB_LOG" 2>&1 &
WEB_PID=$!
while true; do
  if run_command "$DEADLINE_FILE" "$ROOT_DIR" curl --fail --silent --connect-timeout 1 --max-time 2 http://localhost:3100/ >/dev/null 2>&1; then break; else rc=$?; fi
  if ! kill -0 "$WEB_PID" 2>/dev/null; then
    rc=0; wait "$WEB_PID" || rc=$?
    tail -n 40 "$WEB_LOG" >&2
    [ "$rc" -ne 0 ] || rc=1
    exit "$rc"
  fi
  [ "$rc" -ne 124 ] || { tail -n 40 "$WEB_LOG" >&2; fail "Next.js readiness timed out after ${READY_TIMEOUT}s."; }
  sleep .1
done
echo "Ready: API http://localhost:8080/health; web http://localhost:3100; private logs $WEB_LOG"

if $MOBILE; then
  begin_stage 'simulator readiness'
  if [ "$SIM_STATE" != Booted ]; then run_command "$DEADLINE_FILE" "$ROOT_DIR" xcrun simctl boot "$SIM_ID"; fi
  while true; do
    if run_command "$DEADLINE_FILE" "$ROOT_DIR" xcrun simctl getenv "$SIM_ID" HOME >/dev/null 2>&1; then break; else rc=$?; fi
    [ "$rc" -ne 124 ] || fail "Selected simulator readiness timed out after ${READY_TIMEOUT}s."
    sleep .1
  done
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
  if [ -t 0 ]; then python3 "$RUNTIME" tty-save "$TTY_FILE" "$$"; fi
  (cd mobile && PATH="$RUN_DIR/bin:$PATH" exec flutter run --no-pub -d "$SIM_ID") &
  MOBILE_PID=$!
  if [ -t 0 ]; then
    # Leave Flutter in the foreground while Bash remains in its interruptible
    # supervisor loop. Foreground external jobs must not reclaim its terminal.
    set +m
    python3 "$RUNTIME" tty-give "$TTY_FILE" "$MOBILE_PID"
    kill -CONT -- "-$MOBILE_PID" 2>/dev/null || true
  fi
fi
STAGE='running (Ctrl-C to stop owned services)'
while true; do
  if ! kill -0 "$WEB_PID" 2>/dev/null; then
    rc=0; wait "$WEB_PID" || rc=$?
    tail -n 40 "$WEB_LOG" >&2
    [ "$rc" -ne 0 ] || rc=1
    exit "$rc"
  fi
  if [ -n "$MOBILE_PID" ] && ! kill -0 "$MOBILE_PID" 2>/dev/null; then
    rc=0; wait "$MOBILE_PID" || rc=$?
    exit "$rc"
  fi
  sleep .1
done
