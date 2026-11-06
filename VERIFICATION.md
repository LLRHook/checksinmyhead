# Billington — local verification procedure

Last verified: never — no integrated V&V run recorded.

Stack: Flutter/Provider/Drift, Go/Gin/PostgreSQL, Next.js. Sources:
[architecture](docs/technical-overview.md), [API](docs/backend-api.md),
[privacy](docs/privacy.md), [design](DESIGN_SYSTEM.md), live [bugs](bugs.md)/[features](features.md),
verified [history](CHANGELOG.md). File budget: 20 KiB.

## Execution rules

1. Record exact SHA and run all applicable local stages. Failure is RED; missing
   prerequisites/coverage is BLOCKED; skips are never green. Stage 2 uses `local-gate`
   with `scope=full` and `clean`.
2. Keep logs, fixture credentials, backups and report in ignored `.vv/`. This file is
   procedural; change baseline counts/Last verified only on green.
3. Use synthetic data in `billington-vv-*`. Preserve existing developer/production data
   and shutdown volumes. Inventory/back up verification state before authorized reset.
4. Block on Stage 0/1/2/5 failures, Stage 4 migration failure or critical/high performance
   breaches. File gaps via `python3 .cycle/trackers.py`; reuse canonical tickets.
5. Record any missing fixture/integration harness as BLOCKED. Follow
   FEAT-1793644506 (PostgreSQL tests) and FEAT-1793644507 (whole journeys) for missing
   automation; this bootstrap does not invent commands for them.

## Verification data (restore manifest)

Restore via real UI/API contracts, never accounting-row edits. Save synthetic IDs/tokens
in `.vv/fixture-ids.json`; probe/reuse valid entries, recreate invalid ones after reset,
and update the checkpoint. Require every probe to succeed.

| ID | Data | Restore / dependency | Probe |
|---|---|---|---|
| D1 | Two synthetic installations/members and creator, including two distinct people called Alex | Create/join a synthetic tab with supported API/UI flows; store each role credential separately | Authorized GET tab/members shows distinct IDs; one member cannot assume another's share |
| D2 | USD manual dinner: subtotal 100, tax 10, tip 18, total 128; repeated item descriptions; one unpaid/unclaimed remainder | Create through Quick Split and Lazy Mode after D1; reuse fixture checkpoint if it exists | One correct local receipt per save; sum of complete shares is 128.00; duplicate descriptions remain independently selectable |
| D3 | EUR receipt: subtotal 20, tax 2, tip 3, total 25; original and frozen USD metadata | Create after provider wiring is working; verify date/source/rate, then attach to D1 | Original EUR values persist; immutable USD snapshot reconciles; display preference changes never rewrite either |
| D4 | Synthetic receipt image with known printed values and ambiguous-currency/discount variants | Prepare local synthetic images under `.vv/fixtures/`; parse using the configured real provider; never use customer photos | Review shows evidence-based items/currency and flags ambiguity; record extraction result and provider/model |
| D5 | Prior released schema/data snapshot with synthetic legacy bills and valid old links | Restore an isolated snapshot and apply the approved migration procedure; follow FEAT-1793644505 | API boots; old links/data survive; failed backfill blocks readiness; rerun is safe |

## Stage 0 — inventory and fresh isolated stack

- [ ] Record `git rev-parse HEAD`, `git status --short`, prior Verified SHA and tool
      versions: `python3 --version`, `go version`, `flutter --version`, `node --version`,
      `npm --version`, `ruby --version`, `docker compose version`. Match repository pins:
      Go from `backend/go.mod`, Flutter from CI, Node from `web-bill-viewer/.node-version`.
- [ ] Inventory `docker compose ls`, relevant containers/volumes and listeners on 8080,
      8081 and 3100. Block on conflicting ports; preserve unrelated running services.
      Inspect existing verification data against D1–D5 and back up needed verification
      state to `.vv/backups/`. Record incidental/unknown data before any reset.
- [ ] Prepare Appendix A with local-only DB settings and confirm its project identity.
      Reset only labelled synthetic state via `make -C backend reset-test
      TEST_PROJECT="$VV_PROJECT" TEST_OWNER="$VV_OWNER"` after inventory/backup.
      Ordinary `make -C backend down` preserves volumes; never use `down -v`.
- [ ] Run `vv_compose up --build -d postgres bill-service`. Confirm PostgreSQL readiness
      with `vv_compose exec -T postgres pg_isready -U billington_vv -d billington_vv`.
      Run `curl --fail --silent http://localhost:8080/health`; require status OK and the
      intended commit. Record `vv_compose images` and image IDs alongside the clean
      source SHA. The health commit is operator-injected locally; it is not independent
      binary provenance. Stop if image/source identity cannot be tied to this build.
- [ ] Build viewer with `NEXT_PUBLIC_API_URL=http://localhost:8080`; run
      `npm run start -- -p 3100` in `web-bill-viewer`; browse. iOS:
      debug `flutter run` in `mobile`. Release `ApiConfig` targets production: never
      send isolated writes there. Verify signed clients only with approved fixtures.
- [ ] Restore/probe D1–D5; block on missing fixtures/provider/migration support. Record
      the build/profile exceptions, restore IDs and backup path in the run report.

## Stage 1 — static checks and source invariants

- [ ] Run `python3 .cycle/trackers.py lint`: 0 errors/warnings. Confirm clone hooks/merge
      driver with `python3 .cycle/trackers.py install`.
- [ ] Run all rows below in their stated directory; resolve toolchain/dependency drift
      and unexpected lock/generated-source changes before interpreting passes.
- [ ] Review changed auth/DTO boundaries, parameterized SQL, log redaction, provider
      injection, immutable money/quotes and migration readiness. Inspect eager tab/query
      shape and repeat-save/upload loops for hot-path drift.
- [ ] Reconcile docs/ticket acceptance, label proposed/history, avoid duplicate API docs.

| Directory | Static/security command (also in CI) |
|---|---|
| `backend` | `test -z "$(gofmt -l .)" \|\| { gofmt -l .; echo "::error::Run 'gofmt -w .' in backend/"; exit 1; }` |
| `backend` | `go vet ./...`; `go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...` |
| `mobile` | `flutter analyze` |
| `web-bill-viewer` | `npm run lint`; `npm audit --audit-level=moderate` |
| root | `/bin/bash -n dev.sh` |
| root | `for script in .github/scripts/*.rb ops/ci/*.rb; do ruby -c "$script"; done` |

Require every exit0, no applicable vulnerabilities or lock drift.

## Stage 2 — builds and automated tests

Run once, uncached, retaining reports with Bash `set -euo pipefail`.
Root: `export REPORT_DIR="$PWD/.vv/delivery-reports"; mkdir -p "$REPORT_DIR"`.
CI uses absolute `REPORT_DIR` for `reports/`. Keep acquisition locked: `go mod download`/`go mod verify`, `npm ci`, `flutter pub get --enforce-lockfile`;
`pod install --deployment` remains a prerequisite only for separately authorized iOS work.

| Layer / directory | Command (same report flags/files in CI) |
|---|---|
| Go unit + SQLite / `backend` | `go test -race -count=1 -json ./... \| tee "$REPORT_DIR/go-default.jsonl"` |
| Go build / `backend` | `go build ./...` |
| Flutter unit/widget + Drift / `mobile` | `flutter test --no-pub --reporter=json \| tee "$REPORT_DIR/flutter.jsonl"` |
| Web unit / `web-bill-viewer` | `npm test -- --reporter=json --outputFile="$REPORT_DIR/vitest.json"` |
| Web build / `web-bill-viewer` | `npm run build` |
| Local workflow / root | `CASE_REPORT="$REPORT_DIR/local-workflow.json" python3 ops/ci/unittest_report.py scripts/test_local_workflow.py` |
| Ruby / root | `CASE_REPORT="$REPORT_DIR/ruby.json" ruby -r "$PWD/ops/ci/minitest_report.rb" .github/scripts/asc_release_test.rb` |
| Gate / root | `CASE_REPORT="$REPORT_DIR/gate-tests.json" python3 ops/ci/unittest_report.py ops/ci/test_delivery_gate.py` |
| iOS / root | [Report commands](ops/ci/README.md#processed-ios-artifact-authority) |
| Live PG authorization/migrations/readiness / `backend` | `go test -race -count=1 -json -tags=integration ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres \| tee "$REPORT_DIR/go-postgres.jsonl"` |
| E2E/a11y/load | No wired runner: FEAT-1793644507, FEAT-1793644512, FEAT-1793644502; manual stages remain |

Baselines stay unaccepted; builds/stubs are not integration. Validate these files
via [delivery controls](ops/ci/README.md); retain IDs/multiplicity and overlap.
Never rerun solely for counts; missing/zero/skip/failure/malformed selections fail.

Set `BILLINGTON_TEST_POSTGRES_DSN` for PG, e.g.
`host=127.0.0.1 port=<fixture-port> user=billington_test dbname=billington_test sslmode=disable`.
The shared harness fails on missing DSN, nonloopback primary/fallback, wrong user/DB
or schema/options (even empty). Bounded cleanup drops only owned random schemas,
never public. Use the runner for current schemas, independent frozen SQL for legacy,
never models. No skips.

Retain migration/catalog/history/locks/startup/health, all lifecycle/authorization/money
cases: both writer orders, concurrent/lost-response/paid retries, insert/update/deferred
COMMIT rollback, current authority, stable share IDs/paid economics/claim priority and
legacy containment. Preserve HTTP/mobile full/partial/zero/discount/custom-tip/history
([bridge](docs/reviews/2026-11-03-client-v1-bridge.md)). Keep three runs of 100 samples at
10 bills/8 people, 100 bills/10,000 shares, paid/attachment and 500 items/5,000 assignments.
Separate misses/transaction control; compare raw IDs/children/money/quotes/flags/times
via PG lock waits/channels ([lifecycle](docs/reviews/2026-11-03-atomic-lifecycle.md)).

Registry1,2,3: retain rows/columns/PK/FK actions and ledger1/2 bytes. Test structural
backfill/legacy defaults, NULL-safe scoped groups, sequence/default/ownership, strict
prefixes/future drift, rollback/cancel/apply locks and old prefix1/2 startup/verify/reads.
Retain old warm-reader failures/old-writer gates. Prove current
API/HTML on the same observed warm PID/pool1 through owned additive columns/suffix4;
health reads only ledger; verify checks catalogs. Restore1,2,3/data. Test
ready2 reference authority/revision/receipts, persisted response2, same-label denial/
confirmed-owner success, rename-stable cents, explicit unavailable net and raw legacy
snapshots. Interim nonnumerical: exclude exactly four measured parents; numerical/runtime RED.
[Journey](mobile/test/live/README.md) is scoped.
Default apply serves; `--migrate-only` applies/exits; `--schema-mode=verify` verifies/serves.
Health: one ledger query; rerun verify after external DDL. No payer backfill. Use owned
schemas/overlays; retain additive schema/ledger on rollback. Production footprint/
backup/restore/predeploy/drain/rollout need [proof](backend/README.md#postgresql-schema-startup).
[Outcome](docs/reviews/2026-11-06-migration-outcomes.md) is not PgSleep/integrated proof.
[Scoped](docs/reviews/2026-11-06-assignment-snapshot.md)

For local workflow changes, also run `python3 scripts/verify_local_lifecycle.py
--postgres-image sha256:<local-image-id> --output .vv/local-lifecycle-<unique-run>`.
It creates only labelled fixture resources, proves real down/restart preservation and
guarded reset, and retains cleanup. No real simulator/app mutation in stub tests.

For runtime changes, run the [static image harness](backend/README.md#static-runtime-verification)
on both immutable images/owned fixtures; retain controls/cleanup, verify signatures
and scan exact artifacts unsuppressed. No CI/hosting proof. Receipt controls:
[backend](docs/backend-ocr-verification.md), [mobile](docs/mobile-ocr-verification.md).

Retain every [mobile save/reopen, UI and native proof obligation](docs/reviews/2026-11-06-ui-quality-candidate.md#verification-obligations); the linked paragraph preserves the previous requirements verbatim.

- [ ] Record runner IDs/skips/failures from the same run; never use historical totals
      as thresholds. Prove affected regressions, preserving initial failures. Diagnose
      before rerunning; no retry into green or invented coverage/changed-line threshold.

## Stage 3 — integrated functional walkthrough

- [ ] Smoke API health, version policy, currency quote/display endpoints and every
      registered route relevant to the batch using [API contracts](docs/backend-api.md)
      and synthetic IDs/tokens. Cover bill create/read, assignments (single/batch), paid
      share; tab create/read/update, join/members/leave, attach, assignments, finalize,
      settlements/read/paid; receipt parse when configured. Require documented status,
      accounting values and authorization on both success and negative paths.
- [ ] Exercise manual and scanned receipt → review/edit currency → participant/custom
      assignment → Done/local save → share → second browser claim → Review → payment
      handoff → marked-paid. Check totals/cent allocation and one local/remote receipt.
- [ ] Attach the same saved receipt to a trip with valid ownership; add a second member's
      receipt, refresh mobile/web, finalize, then mark a settlement paid. Preserve paid
      state across refresh/restart; reject forbidden post-finalize edits.
- [ ] Repeat with non-USD, duplicate item descriptions, two people named Alex, incomplete
      claims, provider outage, failed upload and retry after restart. Require correct
      original/frozen/display values and no duplicate or false “nothing saved” outcome.
- [ ] Exercise ordinary `/b` and `/t`, historical lazy tab links, absent/wrong tokens,
      installed/cold-start/onboarding/not-installed handoff, duplicate join/returning
      member, invalid invite and successive incoming links. Distinguish stored pending
      invites from proven post-install recovery (FEAT-1793644779).
- [ ] Check local removal/totals on two devices against [scope/failure rules](docs/privacy.md#local-removal-online-retention-and-requests)
      and `mobile/test/local_tab_removal_test.dart`; prove independent reopen.
      Online lifecycle only when implemented. Check settlement confirmation/error/undo
      (FEAT-1793644778), configured/absent payment apps and self-reported paid state;
      no real transfers.
- [ ] Run `gui-walkthrough` on this SHA's isolated stack: browser keyboard/focus/
      contrast; iOS VoiceOver/large text/reduced motion/iPad/small supported iPhone.
      A11y is best-effort pending approval. GUI unavailable → NOT RUN;
      if all other stages pass, obtain an explicit waiver for GREEN ON APPROVAL.

## Stage 4 — adversarial, persistence and performance

- [ ] Attack synthetic ownership boundaries: omitted/empty/wrong source-bill token,
      privileged create fields, cross-tab settlement/share/member IDs, forged name,
      wrong role, stale version, paid-item edits and finalized-tab mutation.
- [ ] Exercise oversized/invalid JSON and collections, negative discounts vs invalid
      accounting, NaN/Infinity, receipt MIME/extension mismatch, rate/proxy bypass,
      concurrency caps and slow requests. Inspect synthetic-sensitive HTTP/SQL logs.
- [ ] Use real PostgreSQL to inject failure between writes and race finalize/assignment/
      paid/attach operations. Retry and restart; require atomicity, one settlement
      snapshot and conserved totals. Run prior-schema D5 upgrade and failed-backfill
      readiness tests. SQLite mocks cannot satisfy this step.
- [ ] Measure warm/cold API latency distribution, query count, full-tab payload and scan
      success/cost at recorded realistic volume. Establish approved budgets, minimum
      samples and noise floor via FEAT-1793644502; mark absent budgets/harness BLOCKED
      for performance acceptance. Compare against prior measured baseline, never a guess.

## Stage 5 — hard constraints and external compatibility

- [ ] Retick anonymous/token-gated isolation, original-bill/link/offline-history
      compatibility, immutable quote provenance, conserved cent totals and truthful
      self-reported payment semantics with Stage 3/4 evidence.
- [ ] Verify actual receipt/currency provider runtime behavior, current supported
      currencies and outage handling. Record external access/config gaps explicitly;
      fake-provider tests prove application wiring only.
- [ ] Execute [public/private qualification](web-bill-viewer/README.md#maintained-public-pages)
      and [privacy release gates](docs/privacy.md#release-sequencing). Keep `/privacy`
      absent; serve `/privacy-policy` before its Settings client ships.
- [ ] Verify a signed public binary's version/build/OS/storefront against live policy,
      valid old links and current API using approved synthetic fixtures. A TestFlight
      processing success or source version number is insufficient.
- [ ] Assess [G/F controls](ops/ci/README.md), provenance, recovery and a11y.
      phase F receipts replace tags. Native/hosted/ASC NOT RUN; rebuilds are not promotion.
      Settings/ownership, queues/credentials, floors/capabilities and drain remain external.
      No hosted mutation or Render/Vercel control-plane work is authorized here.

## Stage 6 — report and ledger

- [ ] Write `.vv/last-run.md` with SHA/prior SHA, each stage's actual result, profile/image
      IDs, restored data/backups, test counts/skips, proved tickets, unresolved failures,
      changed coverage/flakiness and external/GUI limits. Report RED/BLOCKED honestly.
- [ ] Only on a full green run: use `python3 .cycle/trackers.py migrate --all` for genuinely
      pending entries, append the dated Verified entry to CHANGELOG, overwrite counts and
      Last verified here. Never manufacture completions for known open runtime defects.

## Appendix A — isolated local stack recipe

Run in Bash from root; block on port conflicts/unknown data. Use the production API
Dockerfile/built Next; `legacy-web` is explicit compatibility coverage. Back up before reset.

```bash
mkdir -p .vv
export VV_SHA="$(git rev-parse HEAD)"
export VV_PROJECT="billington-vv-${VV_SHA:0:12}"
export VV_OWNER="$(python3 -c 'import uuid; print(uuid.uuid4())')"
cat > .vv/stack.env <<'ENV'
DB_HOST=postgres
DB_PORT=5432
DB_NAME=billington_vv
DB_USER=billington_vv
DB_PASSWORD=vv_synthetic_fixture
DB_SSLMODE=disable
ENV
cat > .vv/compose.override.yml <<'YAML'
x-test-labels: &test-labels
  io.billington.test-owner: ${VV_OWNER:?set VV_OWNER}
  io.billington.test-data: synthetic
services:
  postgres:
    labels: *test-labels
  bill-service:
    labels: *test-labels
    environment:
      RENDER_GIT_COMMIT: ${VV_SHA:?set VV_SHA}
volumes:
  postgres_data:
    labels: *test-labels
networks:
  default:
    labels: *test-labels
YAML
vv_compose() {
  case "${VV_PROJECT:?set VV_PROJECT}" in
    billington-vv-*) ;;
    *) printf '%s\n' 'Refuse a non-verification project' >&2; return 1 ;;
  esac
  DB_HOST=postgres DB_PORT=5432 DB_NAME=billington_vv DB_USER=billington_vv \
    DB_PASSWORD=vv_synthetic_fixture DB_SSLMODE=disable \
    docker compose --project-name "$VV_PROJECT" \
    --env-file .vv/stack.env -f backend/docker-compose.yml \
    -f .vv/compose.override.yml "$@"
}
vv_compose config --quiet
vv_compose ps
```

Keep explicit DB assignments: host exports must not redirect this to an external DB.
Provider checks use approved secure env only. Never print resolved config/secrets.
Read synthetic logs with `vv_compose logs --no-color bill-service`; query via
`vv_compose exec -T postgres psql -U billington_vv -d billington_vv`. Back up the
isolated DB with `vv_compose exec -T postgres pg_dump -U billington_vv billington_vv`
into ignored `.vv/backups/`.

Use `vv_compose down` normally. After inventory/backup and explicit reset authorization,
use `make -C backend reset-test TEST_PROJECT="$VV_PROJECT" TEST_OWNER="$VV_OWNER"`.
All project resources/mounts must pass [ownership checks](backend/README.md#local-test-data-reset)
before deletion; unlabelled pre-existing data is rejected. Preserve normal projects.
Restore/probe D1–D5 after rebuilding; missing fixture support remains BLOCKED.
