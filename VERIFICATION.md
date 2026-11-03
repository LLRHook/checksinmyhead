# Billington — local verification procedure

Last verified: never — bootstrap only; no integrated V&V run has been recorded.

Stack: Flutter/Provider/Drift, Go/Gin/PostgreSQL, Next.js. Authoritative:
[architecture](docs/technical-overview.md), [API](docs/backend-api.md),
[privacy](docs/privacy.md), [design](DESIGN_SYSTEM.md), live [bugs](bugs.md)/[features](features.md),
verified [history](CHANGELOG.md). File budget: 20 KiB.

## Execution rules

1. Record the exact SHA and run every applicable stage locally. Treat failed checks as
   RED and unavailable prerequisites/missing coverage as BLOCKED; never call skips green.
   Use `local-gate` with `scope=full` and `clean` for Stage 2 when executing the protocol.
2. Keep logs, fixture credentials, backups and `.vv/last-run.md` under ignored `.vv/`.
   Keep this file procedural; overwrite baseline counts and Last verified only on green.
3. Use synthetic data in `billington-vv-*`. Preserve existing developer/production data
   and shutdown volumes. Inventory/back up verification state before authorized reset.
4. Block on Stage 0/1/2/5 failures, Stage 4 migration failure or critical/high performance
   breaches. File gaps via `python3 .cycle/trackers.py`; reuse canonical tickets.
5. Record any missing fixture/integration harness as BLOCKED. Follow
   FEAT-1793644506 (PostgreSQL tests) and FEAT-1793644507 (whole journeys) for missing
   automation; this bootstrap does not invent commands for them.

## Verification data (restore manifest)

Restore through the real UI/API contracts; never hand-edit accounting rows. Save IDs
and synthetic tokens in `.vv/fixture-ids.json`. Probe saved IDs first and reuse them
when valid; otherwise recreate the row after reset and replace the checkpoint. Require
a successful probe for every row before proceeding.

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
- [ ] Build the viewer using the matrix command with
      `NEXT_PUBLIC_API_URL=http://localhost:8080`, then start in `web-bill-viewer` with
      `npm run start -- -p 3100`. Point the browser to that viewer. Use an iOS simulator
      debug build (`flutter run` in `mobile`) for local API access. Record this profile
      exception: `ApiConfig` hardcodes the hosted API in release mode. Never run isolated
      write journeys against the release-mode production endpoint. Record actual signed
      public-binary compatibility separately using approved non-customer fixtures.
- [ ] Restore/probe D1–D5; block on missing fixtures/provider/migration support. Record
      the build/profile exceptions, restore IDs and backup path in the run report.

## Stage 1 — static checks and source invariants

- [ ] Run `python3 .cycle/trackers.py lint` first; require 0 errors/warnings. Confirm clone
      merge driver and hooks with `python3 .cycle/trackers.py install`.
- [ ] Run all static/security rows below verbatim in their specified directory. Confirm
      no unexpected lockfile/generated source changes. Resolve installed toolchain or
      dependency drift before interpreting a pass.
- [ ] Review auth boundaries, caller DTOs, parameterized SQL/log redaction, provider
      injection, immutable money/quote metadata and migration readiness in changed code.
      Inspect eager tab reads/query shape and repeat-save/upload loops for hot-path drift.
- [ ] Check affected documentation against code and ticket acceptance. Keep proposed or
      historical work clearly labeled; do not duplicate architecture/API documents.

| Directory | Static/security command (from CI) | Expected |
|---|---|---|
| `backend` | `test -z "$(gofmt -l .)" || { gofmt -l .; echo "::error::Run 'gofmt -w .' in backend/"; exit 1; }` | No formatting drift |
| `backend` | `go vet ./...` | Exit 0 |
| `backend` | `go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...` | No applicable vulnerabilities |
| `mobile` | `flutter analyze` | No issues |
| `web-bill-viewer` | `npm run lint` | No issues |
| `web-bill-viewer` | `npm audit --audit-level=moderate` | Exit 0, including all three current web alerts |
| root | `/bin/bash -n dev.sh` | Bash syntax (also check maintained Bash) |
| root | `ruby -c .github/scripts/asc_api.rb` | Syntax OK |
| root | `ruby -c .github/scripts/asc_next_build.rb` | Syntax OK |
| root | `ruby -c .github/scripts/asc_release.rb` | Syntax OK |
| root | `ruby -c .github/scripts/asc_update_notes.rb` | Syntax OK |

## Stage 2 — builds and automated tests

Refresh this CI matrix after tooling changes. Require locked acquisition (`npm ci`,
`flutter pub get --enforce-lockfile`, `pod install --deployment`, existing Go toolchain/modules)
in a clean environment; inspect lock drift. Go covers SQL/startup/request-error secrecy
and SQLite; PostgreSQL adds lifecycle, adoption, catalog guard v2, history/locks/readiness.

| Layer / directory | Command (CI where wired) | Baseline count |
|---|---|---|
| Go unit + SQLite integration / `backend` | `go test -race ./...` | Not measured in this bootstrap |
| Go build / `backend` | `go build ./...` | Build, not a test count |
| Flutter unit/widget + Drift / `mobile` | `flutter test` | Not measured in this bootstrap |
| Web unit / `web-bill-viewer` | `npm test` | Not measured in this bootstrap |
| Web production build / `web-bill-viewer` | `npm run build` | Build, not a test count |
| Local workflow / root | `python3 scripts/test_local_workflow.py` | Stubbed CLI/ownership regressions; not integrated baseline |
| Ruby release automation / root | `ruby .github/scripts/asc_release_test.rb` | Not yet an integrated baseline |
| Live PostgreSQL authorization + migrations/readiness / `backend` | `go test -race -tags=integration ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres` | Not yet an integrated baseline; test-only DSN required |
| App/browser E2E, a11y, realistic load | No wired automated runner: FEAT-1793644507, FEAT-1793644512, FEAT-1793644502 | Manual stages required; automation gap remains |

For the PostgreSQL row, set only `BILLINGTON_TEST_POSTGRES_DSN` to a dedicated
loopback `billington_test` fixture, for example
`host=127.0.0.1 port=<fixture-port> user=billington_test dbname=billington_test sslmode=disable`.
The shared `internal/testpostgres` harness fails if the variable is absent, primary or
fallback host is not loopback, database/user is not `billington_test`, or caller supplies
schema/options (even empty overrides). It creates an owned random `billington_test_*`
schema and drops only that schema with bounded cleanup. It never initializes public.
Current-schema authorization fixtures execute the actual runner; legacy adoption uses
independently pinned frozen SQL, never current models. No selected test skips.

The row retains migration preservation/catalog/history/locks/rollback, startup and health.
Lifecycle coverage adds concurrent/lost-response/paid finalize retries, insert/update/
deferred-commit rollback, sibling writers in both arrival orders and rollback, current
authority, exact paid share IDs, paid economics, claim priority and legacy containment.
HTTP/mobile fixtures cover full/partial/zero/discount/custom-tip/history conservation.
Three runs of 100 samples measure query/latency targets at 10 bills/8 people,
100 bills/10,000 shares, paid/attachment and 500 items/5,000 assignments. Report misses
and transaction control separately. Compare raw IDs/children/money/quotes/flags/times;
use PG lock waits/channels. See [evidence](docs/reviews/2026-11-03-atomic-lifecycle.md).

Default applies/verifies then serves; `--migrate-only` applies/exits;
`--schema-mode=verify` checks without applying then serves. Health is one live ledger
query; rerun startup verify after out-of-band DDL. No payer backfill runs. Use owned
synthetic schemas/isolated overlays; retain additive schema/ledger on rollback.
Production footprint, backup restore, predeploy and old-writer drain need separate proof:
[backend operations](backend/README.md#postgresql-schema-startup). This is local,
not an integrated pass. Lifecycle acceptance, identity and rollout gates remain open.

For local workflow changes, also run `python3 scripts/verify_local_lifecycle.py
--postgres-image sha256:<local-image-id> --output .vv/local-lifecycle-<unique-run>`.
It creates only labelled fixture resources, proves real down/restart preservation and
guarded reset, and retains cleanup. No real simulator/app mutation in stub tests.

For runtime changes, run the [static image harness](backend/README.md#static-runtime-verification)
against both immutable service images and an owned fixture image. Retain controls,
raw results and cleanup; reverify signatures and scan exact saved artifacts without
suppressions. This local gate is not wired into CI and proves no hosting settings.

- [ ] Enumerate (`go test ./... -list '.*'`, `npm exec -- vitest list`, Flutter/Ruby
      runner output); record actual tests/skips/failures, never historical 202/52 counts.
- [ ] Run the full local gate, collect real execution counts and prove every batch
      ticket with a failing-before/passing-after regression where applicable.
- [ ] Rerun failures once for flakiness; repeat passes only for changes/unresolved concerns.
      Record measured coverage; CI has no changed-line threshold. Never invent one.

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
- [ ] Exercise local remove/delete on two devices and verify honest wording/totals;
      exercise authorized online lifecycle only when implemented. Check settlement
      payment confirmation/error/undo (FEAT-1793644778), configured and absent payment
      apps, and self-reported paid state. Do not send real transfers.
- [ ] Run `gui-walkthrough` in verification mode on the isolated stack at this SHA;
      include browser keyboard/focus/contrast and direct iOS VoiceOver, large text,
      reduced motion, iPad and small supported iPhone. Keep a11y best-effort until a
      specific supported claim is approved. If GUI tools are unavailable, record NOT RUN;
      if all other stages pass, use GREEN ON APPROVAL and obtain an explicit waiver
      before recording a final green run.

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
- [ ] Verify current privacy policy destinations/support contacts, data flows/store label,
      private-page indexing/cache/referrer controls and released-feature claims. PR #149
      intentionally removed viewer `/privacy`; verify the marketing destination instead
      of assuming the missing route itself is a regression.
- [ ] Verify a signed public binary's version/build/OS/storefront against live policy,
      valid old links and current API using approved synthetic fixtures. A TestFlight
      processing success or source version number is insufficient.
- [ ] Inspect publication gates, source/artifact identities, automatic-deploy settings,
      rollback/recovery and required accessibility claims. Prepare evidence without
      dispatching production publication or deleting cloud resources.

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
