# Billington — local verification procedure

Last verified: never — bootstrap only; no integrated V&V run has been recorded.

Use Flutter/Provider/Drift, the Go/Gin API with PostgreSQL, and the Next.js viewer.
Keep [architecture](docs/technical-overview.md), [API contracts](docs/backend-api.md),
[privacy](docs/privacy.md) and [design](DESIGN_SYSTEM.md) as their authoritative references.
Use the root [bugs](bugs.md)/[features](features.md) for live work and
[CHANGELOG.md](CHANGELOG.md) for verified history. VERIFICATION.md budget: 20 KB.

## Execution rules

1. Record the exact SHA and run every applicable stage locally. Treat failed checks as
   RED and unavailable prerequisites/missing coverage as BLOCKED; never call skips green.
   Use `local-gate` with `scope=full` and `clean` for Stage 2 when executing the protocol.
2. Keep logs, fixture credentials, backups and `.vv/last-run.md` under ignored `.vv/`.
   Keep this file procedural; overwrite baseline counts and Last verified only on green.
3. Use synthetic data and a dedicated `billington-vv-*` Compose project. Preserve all
   existing developer/production data and normal-shutdown volumes. Inventory and back up
   the verification project's needed state before an explicitly authorized reset.
4. Hard-block on failures in Stages 0, 1, 2 or 5; hard-block on migration failure or
   critical/high performance breaches in Stage 4. File failures/gaps through
   `python3 .cycle/trackers.py` and reuse an existing canonical ticket where appropriate.
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
      Reset only that project's verified synthetic state after authorization. Never use
      `make down` at the baseline: BUG-1793644513 tracks its destructive `-v` behavior.
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
| root | `ruby -c .github/scripts/asc_api.rb` | Syntax OK |
| root | `ruby -c .github/scripts/asc_next_build.rb` | Syntax OK |
| root | `ruby -c .github/scripts/asc_release.rb` | Syntax OK |
| root | `ruby -c .github/scripts/asc_update_notes.rb` | Syntax OK |

## Stage 2 — builds and automated tests

Use the detected CI Test Matrix below. Refresh commands from manifests/workflows after
any tooling change. Require locked prerequisites (`npm ci`, `flutter pub get`, existing
Go module download/toolchain) in a clean verification environment; inspect lockfile drift.
The default Go suite includes SQL-log secrecy tests at every GORM level, hostile
configuration/identifier/driver-error cases and sanitized startup errors, plus SQLite
repository integration tests. The explicit
PostgreSQL row adds scoped authorization/attachment plus migration/readiness lock,
rollback, compatibility and interruption evidence.

| Layer / directory | Command (verbatim CI) | Baseline count |
|---|---|---|
| Go unit + SQLite integration / `backend` | `go test -race ./...` | Not measured in this bootstrap |
| Go build / `backend` | `go build ./...` | Build, not a test count |
| Flutter unit/widget + Drift / `mobile` | `flutter test` | Not measured in this bootstrap |
| Web unit / `web-bill-viewer` | `npm test` | Not measured in this bootstrap |
| Web production build / `web-bill-viewer` | `npm run build` | Build, not a test count |
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

This local row preserves attachment competition/retry, committed-finalization checks,
membership lock order, stale standalone claims, near-zero/tolerance creation and
calculation-error rollback. It additionally proves fresh/legacy/no-op migrations,
IDs/JSONB/capabilities/quote/display/null-dangling-cross-tab-payer preservation, strict
catalog definitions and immutable checksums/recognizer/history/epoch, compatible additive
prefixes, observed advisory lock waits and schema scope, five-second lock timeout,
DDL/DML/ledger/deferred-commit failures, full pending-batch rollback, connection termination/
context interruption and one-time retry. Actual binaries prove migrate-only and failed
verify startup; both health handlers prove healthy status/commit and generic invalid/
unavailable database responses. The 60s total ceiling and 1s health deadline are enforced;
an earlier caller deadline also interrupts real pending SQL and rolls it back.

Migration default: apply/verify before serving; `--migrate-only` applies and exits;
`--schema-mode=verify` checks without applying then serves. Every applicable command must
use isolated synthetic fixtures. Never try these against hosted data as part of local QA.
Catalogs are checked at startup; health performs one live ledger query, not a full schema
or accounting scan. Remove/alter one control only in an isolated Go overlay to prove a
regression; preserve the shared writer's source. The harness row remains local, not a CI
job. Atomic finalization, stable identity and full accounting PostgreSQL coverage remain
open under FEAT-1793644506 and its dependencies. No integrated count/green is recorded here.

For migration D5, compare raw persisted values and sequence state before/after adoption;
never invoke an ORM normalization hook as the preservation oracle. No historical payer
backfill runs. Preserve additive ledger/columns on application rollback; separately verify
production footprint, backup restore, predeploy privileges and drained old writers before
production adoption or stronger financial/replay guarantees.

- [ ] Enumerate with each runner before execution (`go test ./... -list '.*'`,
      `npm exec -- vitest list`, runner output for Flutter/Ruby); record actual tests,
      skips and failures per layer. Do not import the earlier review's 202/52 counts.
- [ ] Run the full local gate, collect real execution counts and prove every batch
      ticket with a failing-before/passing-after regression where applicable.
- [ ] Rerun failures once to classify flakiness; repeat passing checks only after new
      changes or for a specific unresolved concern. Record coverage if measured; CI has
      no configured changed-line coverage threshold. Never invent a percentage.

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

Run from the repository root in Bash. Create local scratch files only when executing
the protocol; this bootstrap has not run these commands. Block if existing services own
the ports or the selected project contains unknown data. The repository has no separate
production Compose profile; use its production API Dockerfile plus a built Next viewer.
Retain the legacy Go viewer only for an explicitly scoped compatibility check.

```bash
mkdir -p .vv
export VV_SHA="$(git rev-parse HEAD)"
export VV_PROJECT="billington-vv-${VV_SHA:0:12}"
cat > .vv/stack.env <<'ENV'
DB_HOST=postgres
DB_PORT=5432
DB_NAME=billington_vv
DB_USER=billington_vv
DB_PASSWORD=vv_synthetic_fixture
DB_SSLMODE=disable
ENV
cat > .vv/compose.override.yml <<'YAML'
services:
  bill-service:
    environment:
      RENDER_GIT_COMMIT: ${VV_SHA:?set VV_SHA}
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
vv_compose ps
```

Keep the explicit DB assignments in `vv_compose`; exported host variables must never
redirect this recipe to an external database. Provide provider keys through the approved
secure environment only for provider checks;
keep them out of logs. Verify rendered configuration without printing secret values.
Use `vv_compose logs --no-color bill-service` only with synthetic data and sanitized logs.
For a database count/probe, use `vv_compose exec -T postgres psql -U billington_vv -d
billington_vv` and read-only queries. Back up only the isolated verification DB with
`vv_compose exec -T postgres pg_dump -U billington_vv billington_vv` into ignored backups.

Use `vv_compose down` for normal shutdown (preserves the volume). After inventory,
backup and explicit reset authorization, verify the `billington-vv-*` project identity
and use `vv_compose down --volumes --remove-orphans` solely for its synthetic reset.
Keep existing developer Compose projects/volumes untouched. Restore D1–D5 through the
supported API/UI after rebuilding; block on absent idempotent fixture/migration support.
