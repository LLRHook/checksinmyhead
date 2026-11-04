# Technical Overview

Billington is a distributed bill-splitting system with three components: a Go backend API, a Next.js web viewer, and a Flutter mobile app. This document covers the architecture, data models, and key technical decisions.

## Architecture

```
┌──────────────────────┐       ┌──────────────────────┐
│    Flutter iOS App   │       │   Next.js Web Viewer  │
│                      │       │                       │
│  Provider + Drift DB │       │  App Router (RSC)     │
│  HTTP client service │       │  Server components    │
└──────────┬───────────┘       └───────────┬───────────┘
           │                               │
           │         HTTP / JSON           │
           └───────────────┬───────────────┘
                           │
              ┌────────────▼────────────┐
              │     Go API (Gin)        │
              │                         │
              │  Handler → Service →    │
              │  Repository → GORM      │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │    PostgreSQL 17        │
              │                         │
              │  Bills, Tabs, Members,  │
              │  Settlements, Images    │
              └─────────────────────────┘
```

Both retained Go service images use a digest-pinned Distroless
`static-debian13:nonroot` runtime, with CGO disabled in production and execution
as UID/GID 65532. Go supplies DNS/user lookup and TLS without runtime libc/OpenSSL;
race/SQLite tests retain CGO. Their shared same-binary `--healthcheck` mode probes
the established local
HTTP health endpoint before database initialization. The default server commands
and ports are unchanged; see [container liveness](../backend/README.md#container-liveness)
and the [local runtime harness](../backend/README.md#static-runtime-verification).

Local Compose defaults to PostgreSQL and the API, keeping its existing project and
volume identity. Next.js is the ordinary local viewer; the retained Go HTML service
requires the explicit `legacy-web` profile on its unchanged 8081 URLs. Source,
templates, Dockerfile and test coverage remain; external consumers/hosting retirement
are unverified. See [local workflow](../README.md#quickstart).
The Bash entrypoint owns exact container/process cleanup and supervises both local
clients. A Python stdlib helper owns cancellable command deadlines and terminal
handoff. Failed inventory is an error; unresolved partial ownership requires manual
inspection. See the [correction evidence](reviews/2026-11-03-local-workflow-correction.md).

### Request Flow

1. Client sends HTTP request with access token (`?t=token`)
2. Handler parses request, validates token against stored tab/bill token
3. Service executes business logic
4. Repository performs database operations via GORM
5. Response returned as JSON

## Data Models

### Tab

The central grouping entity. Represents a trip or event where multiple bills are tracked.

```go
type Tab struct {
    ID          uint        // Primary key
    Name        string      // e.g. "Beach Trip 2025"
    Description string
    Bills       []Bill      // FK: Bill.TabID
    Members     []TabMember // FK: TabMember.TabID
    TotalAmount float64     // Computed (not stored)
    Finalized   bool        // Locked when true
    FinalizedAt *time.Time
    AccessToken string      // 64-char secure token
}
```

### Bill

An individual expense with line items and per-person share calculations.

```go
type Bill struct {
    ID              uint
    TabID           *uint            // Optional: belongs to a tab
    AddedByMemberID *uint            // Who added this bill
    Name            string
    Subtotal        float64
    Tax             float64
    TipAmount       float64
    TipPercentage   float64
    Total           float64
    Date            time.Time
    PaymentMethods  []PaymentMethod  // JSONB — Venmo, Zelle, etc.
    Participants    []Person         // many2many
    Items           []BillItem       // Line items with assignments
    PersonShares    []PersonShare    // Calculated per-person totals
    AccessToken     string
}
```

### TabMember

Anonymous identity for collaboration without accounts.

```go
type TabMember struct {
    ID          uint
    TabID       uint
    DisplayName string   // User-chosen name
    MemberToken string   // 64-char token for attribution
    Role        string   // "creator" or "member"
    JoinedAt    time.Time
}
```

### TabSettlement

Created once when a tab is finalized. Stores gross allocated USD by legacy name key; net payer balances and the two independent paid flags retain their separate meanings.

```go
type TabSettlement struct {
    ID         uint
    TabID      uint
    PersonName string
    Amount     float64
    Paid       bool      // Toggle via PATCH
}
```

## Backend Service Layer

Each domain module follows the **Handler → Service → Repository** pattern:

```
internal/
├── bill/
│   ├── handler.go      # HTTP handlers, request parsing, response formatting
│   ├── service.go      # Business logic interface + implementation
│   └── repository.go   # Database queries via GORM
├── receipt/
│   ├── handler.go      # Multipart upload, MIME validation
│   └── service.go      # Anthropic Claude Messages API integration
├── tab/
│   ├── handler.go      # Tab CRUD, join, finalize, settlements
│   ├── service.go      # Finalization logic, member management
│   └── repository.go   # Tab queries with eager loading
```

**Handler** — Parses HTTP requests, validates access tokens, calls service methods, returns JSON responses. No business logic lives here.

**Service** — Validates typed commands and delegates a complete mutation to its repository. Handlers parse capabilities and DTOs; current authority/state decisions live inside the locked transaction.

**Repository** — Owns authorization, lock ordering and commit for each database transition. Read endpoints may preload nested associations. Finalization batch-projects frozen accounting and persisted share components without Bill normalization or item/participant/payment graphs.

## Frontend Architecture

### Flutter (Mobile)

- **State Management**: Provider pattern for unidirectional data flow
- **Local Database**: Drift ORM (SQLite) for offline bill storage and tab metadata
- **API Client**: HTTP service for backend communication with fire-and-forget sync
- **Schema Migrations**: Drift schema v8

`ApiService.buildBillRequest` remains the creation serialization owner. It omits valid
zero assignment entries without changing Provider state, participants or zero shares,
and rejects invalid percentages. Receipt participant entry (typed, recent, auto-added
self and groups) and upload share the endpoint's 30-Unicode-code-point name check.
Groups validate every member before adding any. Done validates through the builder
before local serialization; explicit history Get Link surfaces validation errors while
retaining the stored receipt. This does not resolve the separate save/replay operation
or the established client/server one-cent tie mismatch.
Pending-history upload checks the original saved assignment values before its display
projection, using the serializer's shared percentage rule. Name checks match the
endpoint's whitespace set, including retained U+FEFF. See [review corrections](reviews/2026-11-03-client-validation-correction.md).

### Next.js (Web Viewer)

- **Rendering**: App Router with React Server Components for initial data fetch
- **Pages**: `/b/[id]` for bill viewing, `/t/[id]` for tab viewing
- **Client Components**: LazyBillBoard, MemberList, and bill/tab breakdowns
- **Settlements**: Presentational `SettlementCard` shows names, amounts and paid status,
  directs status updates to Billington, and retains the external Venmo link. The sole
  tab-page caller has no writable browser settlement mode or mutation helper.
- **API Client**: `src/lib/api.ts` with typed fetch functions and `computeTabPersonTotals` aggregation

## Key Technical Decisions

### Anonymous Tokens Instead of Accounts
Users never create accounts. Access is controlled by 64-character cryptographic tokens generated with Go's `crypto/rand.Text()`. Tab creators and members each receive unique tokens that are stored locally on their devices.

Public bill creation accepts an explicit content contract and always creates a fresh
standalone graph. One transactional attachment operation requires independent bill/tab
capabilities, resolves member attribution inside the destination, and locks tab before
bill. Same-tab retries preserve original attribution. Membership writers take the same
tab lock; standalone claims recheck `tab_id IS NULL` at their locked write boundary.
Creation validates and derives shares once in the service before display or frozen
quoting. Raw share components and aggregate obligations are checked before the shared
cent allocator; remainder work is bounded by participant count. Calculation failures
propagate through claim transactions so assignments and old shares roll back together.
One required Frankfurter v2 pair client is composed once for creation, USD preview
and display. The receipt policy owns twelve approved codes, independently of broader
provider-defined display pairs such as ZAR. The adapter validates exact pairs/rates/
observation days, bounds upstream bodies and cancellation, and makes one attempt per
distinct pair within the creation's shared five-second quote budget. No backend TTL
rate map or redundant ExchangeRate-API adapter remains; ordinary HTTP pooling and
immutable stored quotes remain. Frozen USD source/date are never display metadata;
distinct persisted display provenance waits for migration 0002. Historical quotes and
explicit zero totals are preserved on reads. Tab summaries and share allocation use
one checked frozen USD audit; sums use checked cents and never display/native foreign
fallbacks. Missing/inconsistent valuation requires an authorized accounting review,
without fetching or rewriting history. Mobile caching/decoding/save/replay and
versioned JPY precision remain open. See [API contracts](backend-api.md#currency-quotes)
for accepted fields, ownership, freshness and legacy compatibility.
`FinalizeOnce` is the sole production finalization seam: tab capability, current creator
or memberless policy, stored-result validation, gross allocation, bounded inserts and
one checked active-state update commit together. Authorized retries read the stored
snapshot without writes/recalculation. Ambiguous legacy results and unsafe accounting
return `409 accounting_review_required`. Individual receipt reads remain available;
tab summaries also return that review response when frozen USD evidence is unavailable
or inconsistent, after checking tab access. Stored historical rows remain unchanged.

Every attached writer uses Tab → ascending Bills → ascending Items → Shares; settlement
writes use Tab → Settlement. Join/leave/settings take Tab first. Fresh tab/creator creation
is atomic. Source-share payment discovers association without locks and permits at most
one standalone-to-attached restart under the same 10-second request context. Lifecycle monetary projections
use checked cent conversion/sums and the existing bounded remainder semantics.

`bill.ReplaceAssignmentsLocked` owns single/batch share refresh for both contexts. It
batch-loads/locks/persists, preserves claim timestamps and unchanged economic share IDs,
and rejects paid percentage/component/total/ordered-item/frozen-USD changes. Paid routes
use exact scoped share IDs; flags remain editable after finalization without recalculation.
Leaving cannot delete creator or recorded payer/adder provenance. Join retries cannot
turn an invalid supplied capability into replacement membership.

Stable participant identity, the positive-only USD read fallback, legacy missing-payer/net
presentation and receipt replay/save remain separately owned. Schema compatibility does
not establish the guarantee during overlap with old uncooperative writers. No deployment,
production adoption, signed-client bridge or whole-product acceptance is claimed.

### JSONB for Flexible Data
`PaymentMethods` and `PersonShare.Items` use PostgreSQL JSONB columns via GORM's `serializer:json` tag. This avoids extra join tables for data that is always read and written as a unit.

Both database-using binaries share the SQL logger and sanitized database initialization errors. The logger suppresses SQL text, parameters, arbitrary messages and invalid configuration text; it emits bounded operation/table/error categories, known SQLSTATE codes, timing and row counts. Bind interpolation is disabled for logging. Unknown identifiers and error codes never pass through as text. Bill, tab and legacy-web request-error sinks use the same finite classification while retaining original typed errors for business and HTTP-status decisions.

### Immutable PostgreSQL Schema and Readiness

Both `bill-service` and the retained `web-service` use `migrations.Run` through the
shared database initializer. One embedded ordered registry replaces runtime AutoMigrate.
Only `0001_baseline.sql` is implemented: its released `81a564f`/`f1d62374` DDL checksum
and the independent catalog recognizer/manifest/ledger checksums are pinned with provenance.
Version 0002 is reserved for later receipt replay/display metadata.

A schema-scoped transaction advisory lock precedes ledger inspection/creation. At Read
Committed, the next starter rereads committed history after waiting. The checked transaction
covers all pending SQL, validation and ledger entries; commit/rollback errors fail startup.
Limits are 5s for lock acquisition and 60s total. Empty targets receive frozen DDL;
unledgered legacy targets must match actual catalog definitions (including defaults,
sequence ownership, FK actions and index keys/uniqueness/predicates), not object names.
Unrelated tables/extension objects are excluded. Unknown/partial footprints fail closed.

Independently pinned startup guard v2 also rejects related inheritance, disabled or
replica-only internal FK enforcement and replica sessions. It supplements frozen v1
recognition without changing its SQL/manifest/ledger checksums or recorded history.
Unrelated inheritance and ordinary/always-enabled FK triggers remain compatible.

The append-only `schema_migrations` ledger stores version/name, exact SQL and validation
SHA-256 digests, compatibility epoch and database timestamp. Known prefix changes, gaps
and unsupported epochs fail. Same-epoch reviewed additive later versions may coexist
with an older schema-aware binary without downgrading history; no destructive downgrade
runs. Registry/recognizer v1 must not be regenerated from evolving models.

The unchecked payer backfill is retired, with no historical rewrite or financial
recalculation. Null/dangling/cross-tab payer references, old IDs, capabilities, JSONB,
quotes, display values and payment flags remain unchanged. Later financial operations
must contain/review legacy payer anomalies explicitly.

Default invocation applies/verifies and serves; `--migrate-only` applies and exits;
`--schema-mode=verify` checks without applying before serving. Invalid arguments fail
closed. Readiness requires successful startup validation plus one bounded live ledger
query (1s) with a compatible known prefix; it has no accounting preload/provider/cache.
Catalogs are revalidated at startup, so out-of-band DDL requires rerunning verify.
`/health` preserves status/commit on success and returns generic 503 otherwise.

The shared integration-tagged `internal/testpostgres` harness rejects missing, nonlocal,
wrong-user/database and caller schema/options DSNs; it owns/deletes only random schemas.
Current-schema authorization tests execute the actual runner; independent frozen legacy
fixtures prove adoption. Local schema proof is separate from production catalog adoption,
backup/restore, host predeploy/privileges and draining old writers. Retain additive schema
and ledger on application rollback. Never return to replay-ignorant servers after keyed
clients activate; see [backend operations](../backend/README.md#postgresql-schema-startup).

### Monolith Over Microservices
A single `bill-service` binary handles all endpoints. The layered architecture (handler/service/repository) provides separation of concerns without the operational overhead of multiple services.

### Anthropic Claude for Receipt OCR
Receipt scanning sends a selected image from the mobile app to the backend. The backend sends the image to Anthropic's Claude Messages API with an extraction prompt and returns parsed receipt fields. The receipt parsing endpoint does not persist the uploaded image.

### Local-First Mobile
The Flutter app maintains its own Drift database for offline access and fast reads. Backend sync is fire-and-forget — the app works without network access for local bills.

### Shared HTTP lifecycle and admission

`pkg/safehttp` owns both binaries' explicit HTTP server deadlines (5s headers, 20s
read, 50s write, 60s idle, 32 KiB MaxHeaderBytes), signal-owned request cancellation
and 25s graceful shutdown followed by Close. Its router constructor installs finite
recovery in every Gin mode, an opaque standard-server log sink, and the configured
trust-none-by-default proxy policy. Panic diagnostics contain only a fixed event,
category and allowlisted route pattern. Partial responses and disconnects abort.

One process-wide eight-slot gate covers JSON mutation routes before decoding, with
503/Retry-After on saturation and no queue. Reads/health bypass it; Content-Type does
not select admission. The shared decoder enforces one document/EOF under each caller's
byte cap and retains strict versus ignored unknown-field contracts. Content DTO arrays
count elements before typed slice allocation, then enforce aggregate bounds before
model copies. Domain authorization, accounting and PostgreSQL atomicity stay in their
existing owners. CreateTab has a 16 KiB body cap and sanitized code-point limits;
see the [API policy](backend-api.md#http-resource-policy) for exact limits and errors.

`TRUSTED_PROXY_CIDRS` accepts a bounded explicit canonical CIDR list. Only XFF is used;
platform and X-Real-IP trust are disabled, and mapped client IPv4 addresses normalize
to one identity. No hosted network ownership or verified deployment configuration is
inferred. Receipt gate/provider/mobile work and durable allowance remain separate work.

## Security Model

- **Token-based access**: Every tab and bill has a unique access token. Protected reads accept a bearer token or the legacy `?t=` link parameter.
- **No accounts**: Billington does not ask users to create accounts, but shared bills and tabs contain user-provided names and payment handles and are stored online.
- **Member attribution**: Write operations optionally accept `?m=memberToken` for attribution without authentication.
- **CORS**: Restricted to configured browser origins; CORS is not an authorization control.
- **Receipt scan limits**: Receipt parsing is limited to 10 requests per minute per client IP and images are limited to 10MB.

## Testing Strategy

### Backend (Go)
Unit tests cover command forwarding, checked gross projections/rounding, finite errors and creation contracts. PostgreSQL tests use the strict owned-schema harness for HTTP, observed lock waits, both arrival orders and rollback, commit failures, paid protection, authority changes and 3×100-sample query/latency measurements. SQLite tests remain useful without claiming PostgreSQL lock semantics.

```bash
cd backend && go test -race ./...
```

### Web Viewer (Vitest)
Tests for API client functions and the `computeTabPersonTotals` aggregation logic. Fetch is mocked with `vi.stubGlobal` for HTTP error path testing.

```bash
cd web-bill-viewer && npm test
```

### Flutter
Widget and unit tests for the mobile app.

```bash
cd mobile && flutter test
```
