# Billington

**Privacy-first bill splitting for group trips** — [Demo](https://youtube.com/shorts/T1GHR6JgOX8?feature=share) | [Website](https://getbillington.vercel.app/)

Billington lets groups split bills, track expenses, and settle up — all without creating accounts. Share a link, add bills, and see who owes what.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Flutter App   │     │  Next.js Viewer  │
│   (iOS mobile)  │     │  (web client)    │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
          ┌──────────▼──────────┐
          │   Go API (Gin)      │
          │   port 8080         │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │   PostgreSQL 17     │
          └─────────────────────┘
```

## Quickstart

<!-- cycle:tracker-setup begin (written by trackers.py install) -->
**Once per clone**, set up the tracker merge driver and pre-commit lint (Claude Code sessions do this automatically):

```bash
python3 .cycle/trackers.py install
```

```powershell
python .cycle\trackers.py install
```
<!-- cycle:tracker-setup end -->

Use Node **24**, npm **11**, Docker with `docker compose`, Python 3, curl and
lsof. Full iOS development also needs Flutter **3.41.5**, CocoaPods **1.16.2**,
Xcode and an available iOS simulator. Pins come from the web `.node-version`, CI
Flutter pin and committed `Podfile.lock`.

```bash
./dev.sh setup             # Explicit locked acquisition; preserves existing env files
./dev.sh                   # PostgreSQL + API + Next.js + Flutter
# Backend/web only (no Flutter, CocoaPods or simulator required):
./dev.sh setup --no-mobile
./dev.sh --no-mobile
```

Setup uses `npm ci`, `flutter pub get --enforce-lockfile` and
`pod install --deployment`. It creates only missing local environment examples.
Normal startup installs nothing; missing/stale prerequisites point back to setup.
For iOS, use the sole booted available simulator, or select one explicitly:
`BILLINGTON_SIMULATOR_ID=<UDID> ./dev.sh`. Ambiguous selection fails before services
start; no simulator is erased or shut down. Flutter keeps terminal hot reload/quit.

Readiness waits are bounded (90 seconds per stage; `BILLINGTON_READY_TIMEOUT=1..180`
can adjust this). Occupied ports are refused. Ctrl-C stops only containers/process
groups started by this invocation; pre-existing running backend services keep running.
Stopped containers are reused; rebuild intentionally with `make -C backend up` when
source/config changes. Private web logs remain at the unique path printed by startup;
inspect/remove that run directory when finished. Acquisition errors retain their
original diagnostics and status.

For manual operation after setup:

```bash
make -C backend up        # PostgreSQL/API, foreground
# In another terminal:
(cd web-bill-viewer && npm run dev)  # http://localhost:3100
# Normal shutdown, preserving PostgreSQL data:
make -C backend down
```

The retained Go HTML viewer runs only with `docker compose --profile legacy-web up
--build` from `backend`, on its original port 8081. Its source, templates, image and
tests remain supported for compatibility; external consumers have not been ruled out.
See [local reset and verification](backend/README.md#local-test-data-reset) for the
separate guarded destructive operation. Never use a volume reset for ordinary shutdown.

Backend startup applies/verifies the immutable PostgreSQL migration registry before
serving. The existing binary also supports `--migrate-only` (apply and exit) and
`--schema-mode=verify` (verify without applying, then serve). Both maintained service
binaries share the policy; `/health` checks the live database/ledger within one second.
See [backend startup and rollback](backend/README.md#postgresql-schema-startup) for strict
legacy adoption, preserved historical payer data and unresolved production rollout gates.

## Project Structure

```
billington/
├── backend/                  # Go API server
│   ├── cmd/bill-service/     # Main entrypoint
│   ├── internal/             # Business logic (bill, tab, receipt, currency)
│   │   ├── bill/             #   Bill CRUD (handler/service/repo)
│   │   ├── receipt/          #   Receipt OCR via Anthropic Claude API
│   │   ├── tab/              #   Tabs, members, settlements
│   ├── pkg/                  # Shared packages
│   │   ├── models/           #   GORM data models
│   │   ├── database/         #   PostgreSQL connection
│   │   └── security/         #   Token generation
│   ├── migrations/           # Immutable ordered PostgreSQL SQL + catalog recognizer
│   ├── docker-compose.yml    # PostgreSQL + bill-service
│   └── Makefile
├── web-bill-viewer/          # Next.js web client
│   ├── src/app/              # App Router pages
│   │   ├── b/[id]/           #   Bill viewer (/b/:id?t=token)
│   │   └── t/[id]/           #   Tab viewer (/t/:id?t=token)
│   │   └── privacy/          #   Public privacy policy
│   ├── src/components/       # React components
│   └── src/lib/api.ts        # API client + types
├── mobile/                   # Flutter iOS app
│   └── lib/                  # Dart source
├── docs/                     # Project documentation
│   ├── technical-overview.md
│   ├── backend-api.md
│   └── privacy.md
├── dev.sh                    # Full-stack dev startup
└── README.md
```

## Core Concepts

### Tabs
A Tab is a group expense tracker (e.g. "Beach Trip 2025"). Multiple bills are added to a tab, and per-person totals are calculated across all bills. When the trip is done, the creator finalizes the tab to lock it and generate settlement amounts.

### Anonymous Member Tokens
No accounts needed. When someone creates a tab, they get an access token. Others join via a shared link and receive a member token. Tokens are stored locally and used to authorize shared-tab access and attribute bill contributions.

### Finalization & Settlements
The tab creator can finalize a trip to aggregate each person's shares across its bills and create settlements. Settlements can be toggled as paid.

## Development workflow

Read [AGENTS.md](AGENTS.md) for shared contributor/agent rules. Use the root
[bugs.md](bugs.md) and [features.md](features.md) as the active backlog, with Jira off.
Create and update entries through `python3 .cycle/trackers.py`; see
[.cycle/TRACKERS.md](.cycle/TRACKERS.md). Run `python3 .cycle/trackers.py lint` after
tracker changes and merges. Complete relevant local checks and affected documentation
before review; [VERIFICATION.md](VERIFICATION.md) defines the exact local matrix and
isolated receipt/save/share/claim/attach/finalize/paid journeys. Its bootstrap is an
unexecuted procedure, with missing integration coverage explicit. Only integrated V&V
migrates completed tickets into
[CHANGELOG.md](CHANGELOG.md).

The [foundation baseline](docs/reviews/2026-11-02-baseline.md) records the approved scope
and evidence reconciliation. Existing architecture and API documents linked below
remain authoritative. Procedure preparation does not establish release readiness.

## Testing

Run these from the repository root in separate shells; see [VERIFICATION.md](VERIFICATION.md)
for static/security/build commands, prerequisites, skip accounting and full acceptance.

```bash
# Backend (Go)
cd backend && go test -race ./...

# Web viewer (Vitest)
cd web-bill-viewer && npm test

# Flutter
cd mobile && flutter test
```

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Mobile | Flutter / Dart | iOS app with Drift DB, Provider state |
| Web | Next.js 16 / React 19 | Server-rendered bill & tab viewer |
| API | Go / Gin | REST API with layered architecture |
| Database | PostgreSQL 17 | Primary data store via GORM |
| AI/OCR | Anthropic Claude | Receipt scanning via Messages API |
| Infra | Docker Compose | Local development environment |

## Roadmap

- [x] Foundation — Go API, PostgreSQL, Bill CRUD
- [x] Bill Sharing — Web viewer, Venmo deep links
- [x] Tabs & Group Trips — Multi-bill tabs, per-person totals
- [x] Receipt Scanning — Selected receipt images parsed through Anthropic Claude
- [x] Finalization — Settlements, paid tracking
- [x] Account-less Collaboration — Anonymous member tokens
- [x] Documentation & Testing — Tests, docs, dev script
- [x] Receipt OCR — Anthropic Claude API for receipt scanning
- [ ] Production Deployment — Cloud hosting, CDN, monitoring

## Documentation

- [Technical Overview](docs/technical-overview.md) — Architecture, data models, design decisions
- [Backend API Reference](docs/backend-api.md) — Full endpoint documentation
- [Privacy](docs/privacy.md) — What Billington stores and sends to service providers
- [Market Analysis](docs/market-analysis.md) — Competitive landscape
- [Contributing](docs/contribution.md) — Development guidelines

## License

GNU GPL — see [LICENSE](LICENSE).
