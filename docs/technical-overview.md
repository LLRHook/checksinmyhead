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
- **Schema Migrations**: Drift schema v9

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

Public bill creation accepts an explicit content contract. Unkeyed requests create
independent standalone graphs; keyed requests recover the original persisted creation. One transactional attachment operation requires independent bill/tab
capabilities, resolves member attribution inside the destination, and locks tab before
bill. Same-tab retries preserve original attribution. Membership writers take the same
tab lock; standalone claims recheck `tab_id IS NULL` at their locked write boundary.
Creation normalizes and validates before indexed replay lookup. Only a miss derives
shares and obtains bounded display/frozen quotes; the service owns secure token creation.
The repository elects a parent with digest-only `ON CONFLICT DO NOTHING`, then inserts
checked 500-row child batches only for the winner in one checked Read Committed
transaction. A loser uses a new scalar SELECT in that transaction; the handler uses
the acknowledged persisted201 fields. No replay graph enters fresh-creation guards. Raw share components and aggregate obligations are checked before the shared
cent allocator; remainder work is bounded by participant count. Calculation failures
propagate through claim transactions so assignments and old shares roll back together.
One required Frankfurter v2 pair client is composed once for creation, USD preview
and display. The receipt policy owns twelve approved codes, independently of broader
provider-defined display pairs such as ZAR. The adapter validates exact pairs/rates/
observation days, bounds upstream bodies and cancellation, and makes one attempt per
distinct pair within the creation's shared five-second quote budget. No backend TTL
rate map or redundant ExchangeRate-API adapter remains; ordinary HTTP pooling and
immutable stored quotes remain. Frozen USD source/date are never display metadata;
migration 0002 stores separate nullable display day/source/retrieval receipts. Native
display uses `same_currency` without a market/retrieval timestamp. Historical quotes and
explicit zero totals are preserved on reads. Tab summaries and share allocation use
one checked frozen USD audit; sums use checked cents and never display/native foreign
fallbacks. Missing/inconsistent valuation requires an authorized accounting review,
without fetching or rewriting history. Mobile `RecentBillsManager` now owns the
Drift9 save/resume transaction, immutable request and exact-ID checkpoints; Done,
launch/history retry and tab additions enter that owner. Its API/storage/key-store
seams expose durable publication, valuation and attachment results. No time/content
deduplication or newest-row identity lookup remains on that path. Imported tab
snapshots cannot acquire source/publication authority. Pending/referenced receipts
survive capacity handling; inability to evict safely fails the new transaction.
Foreign values without an audit stay unavailable; frozen zero stays zero. Display
rates are temporary values and never write frozen quote columns. Versioned JPY
precision and the known local/server `.005` allocation difference remain open. See [API contracts](backend-api.md#currency-quotes)
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
presentation, native Keychain qualification and combined mobile journeys remain open.
The narrow iOS MethodChannel uses OS random32 bytes and generic-password Keychain
items accessible only when unlocked on this device, with foreground admission and
create-if-absent retrieval on duplicate add. Drift stores only its nonsecret locator;
existing bearer URLs elsewhere remain plaintext. Missing/locked/error are distinct;
an attempted publication cannot mint a replacement key. Unsupported platforms have
no fallback. The unsigned simulator currently lacks the required Keychain entitlement
(`-34018`); source/build and host/wire proof do not satisfy the native gate. Schema compatibility does
not establish the guarantee during overlap with old uncooperative writers. No deployment,
production adoption, signed-client bridge or whole-product acceptance is claimed.

### JSONB for Flexible Data
`PaymentMethods` and `PersonShare.Items` use PostgreSQL JSONB columns via GORM's `serializer:json` tag. This avoids extra join tables for data that is always read and written as a unit.

Both database-using binaries share the SQL logger and sanitized database initialization errors. The logger suppresses SQL text, parameters, arbitrary messages and invalid configuration text; it emits bounded operation/table/error categories, known SQLSTATE codes, timing and row counts. Bind interpolation is disabled for logging. Unknown identifiers and error codes never pass through as text. Bill, tab and legacy-web request-error sinks use the same finite classification while retaining original typed errors for business and HTTP-status decisions.

### Immutable PostgreSQL Schema and Readiness

Both `bill-service` and the retained `web-service` use `migrations.Run` through the
shared database initializer. One embedded ordered registry replaces runtime AutoMigrate.
Frozen `0001_baseline.sql` retains its released `81a564f`/`f1d62374` DDL checksum
and independent catalog recognizer/manifest/ledger provenance. Additive
`0002_receipt_replay_display.sql` appends six nullable columns, two exact CHECKs and
one immediate, NULL-distinct unique bytea btree index. Its independent per-step
recognition checksum pins all nine definitions/enforcement before removing only
those validated additions from a copy for frozen baseline recognition. No defaults,
backfill or historical row1/applied_at change. Known prefixes remain strict; compatible
same-epoch unknown suffixes are retained. See [replay procedure](backend-replay-verification.md).

Additive `0003_participant_identity.sql` appends the participant identity schema
foundation with independently pinned PG17.11 recognition of 90 new definitions.
Frozen SQL/catalog-v1, the nine v2 definitions, ledger DDL and safety-v2 remain
unchanged. Exact v3 definitions are checked before subtraction, then v2 and v1;
known1/2/3 prefixes are strict and future suffixes cannot conceal known drift.
Structural IDs/labels/person-ID ordinals/location and assignment bill IDs infer no
historical identity or rounding ties. Original columns/PK/FK actions and all financial
values remain. NULL-safe pending generation and last-decision receipts retain scoped
member/actor references; cross-row revision validation belongs to later locked behavior.
Application writes still default to graph1/`legacy_review`, with no new serialized
fields/capability/version negotiation. Fresh graphs, response2, reference authority,
legacy containment and clients remain separate identity work.
Actual old prefix1/2 readers pass against0003 after restart. Warm cached readers
returned500 immediately after additive DDL; a separate pgx control reproduced
SQLSTATE0A000 for cached `SELECT *` result-type invalidation. Drain readers before
DDL and replace connections before resuming; verify this operational exclusion
independently. Restarted read compatibility proves neither uninterrupted overlap
nor old-writer safety. A stable-projection/connection strategy needs separate review
and actual binary proof; never blindly retry a mutation. Production adoption remains
unauthorized.
See [foundation evidence](reviews/2026-11-05-identity-foundation.md).

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
Receipt scanning sends a selected image to the optional backend receipt route,
which performs no database statements or image persistence. `internal/receipt`
owns one policy/admission module: 2 slots (configurable 1–8), no queue, 40s operation
before upload and 30s provider context, with earlier caller/socket deadlines winning.
A slot stays held until actual upload/encode/network/read/parse work exits. Bounded
peer state owns ten admissions/60s, 4096 keys and a joined 15s sweeper; denials do not
charge or extend expiry. Admission samples time once under its mutex; sweeping
also samples after locking. Shared safehttp rejection interrupts incomplete uploads
without a second drain/deadline implementation. Lifecycle shutdown joins the sweeper
and cancels/joins private provider leases, idle readers and the pool timer after
serving stops.

The 10 MiB TOTAL multipart cap, parsed part/header caps, verified HTTPS HTTP/1 pool,
fixed Anthropic endpoint/model/prompt/schema/output limit, nonreplayable POST,
redirect refusal, joined DNS/socket/TLS/request/final-Flush completion (including
early responses), raw-socket close without partial/error-body drain, decoded
response/text caps and pre-allocation shape/checked quantity
validation live in this owner. Base64 is encoded once and sent between small JSON
envelope fragments to avoid extra full-image copies. Errors retain only finite
codes/retry seconds; upstream text/causes/Location never enter application errors
or native HTTP pool diagnostics. The private Go resolver owns query sockets and
joins lookup cleanup while retaining stdlib hosts/search/UDP/TCP behavior. Numeric
provider TCP attempts are serial within existing deadlines: one provider socket per
reservation, with DNS/address-selection sockets separate. Healthy idle TLS sockets
reuse only after a duplex interruption/join. Dirty/stale selected idle sockets fail
without redial/retry; legitimate TLS control traffic can conservatively fail one
operation too. Deployment resolver/address-family/roots behavior remains a separate
qualification. See the
[API contract](backend-api.md#post-apireceiptsparse) and
[verification procedure](backend-ocr-verification.md). Process/IP controls multiply
across replicas. Durable account allowance B is deferred. Neither hosted capacity nor
provider acceptance of every admitted size/format has been verified.

Mobile `ReceiptApiService` owns each attempt's `ReceiptIoClient`, abort trigger, full-body
subscription and 45s deadline from before setup through parse and cleanup. A separate
private upload owner retains the original input subscription and joins its one
asynchronous cancellation future, including source errors and cancellation during
listen. Native send completion alone does not establish input cleanup. The private
transport retains upstream and paired loopback sockets throughout SDK TLS handoff;
its joined teardown terminates the reproduced silent-ClientHello stall. Acceptance
matches the actual local endpoint, retaining at most eight accepted endpoints before
finite failure; no fallback/retry is added. The ordinary paired topology costs two
extra TCP descriptors and a transient listener, excluding SDK DNS/staggered setup
and OS transients. Default TLS trust/hostname verification and SDK/http parsing stay
in place; no new dependency or protocol parser is used. Full physical/signed-client
and native DNS lifetime acceptance is still pending. The client closes on every outcome; cancellation
does not consume a future manual
attempt. Decoded bodies are capped at 1 MiB before bounded JSON preflight/typed graphs;
redirects and automatic retries are disabled. A monotonic check after synchronous
parse prevents late success; a timer cannot preempt synchronous CPU work.
`ParsedReceipt` is the shared validation/quantity-distribution owner for network,
review and direct bill callers. `BillData` builds a complete bounded replacement
before mutating currency/items/controllers or notifying. The scan widget owns service
disposal and checks its active attempt after network/picker/review continuations.
Appearance, navigation, quote/JPY policy and manual confirmation remain. See the
[mobile procedure](mobile-ocr-verification.md) and
[integration evidence](reviews/2026-11-04-mobile-tls-integration.md); backend independent review,
real provider, simulator/signed public binary and whole-product gates are separate.

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
model copies. Decoder/admission rejection expires body-read deadlines and closes
HTTP/1 connections, bounding transport cleanup beyond the handler. Domain
authorization, accounting and PostgreSQL atomicity stay in their
existing owners. CreateTab has a 16 KiB body cap and sanitized code-point limits;
see the [API policy](backend-api.md#http-resource-policy) for exact limits and errors.

`TRUSTED_PROXY_CIDRS` accepts a bounded explicit canonical CIDR list. Only XFF is used;
platform and X-Real-IP trust are disabled, and mapped client IPv4 addresses normalize
to one identity even with an unused malformed left prefix. Invalid hops remain for
Gin's right-to-left trust/fallback decisions. No hosted network ownership or verified
deployment configuration is inferred. Receipt admission consumes the same normalized
identity. Mobile cancellation and
durable allowance remain separate work.

## Security Model

- **Token-based access**: Every tab and bill has a unique access token. Protected reads accept a bearer token or the legacy `?t=` link parameter.
- **No accounts**: Billington does not ask users to create accounts, but shared bills and tabs contain user-provided names and payment handles and are stored online.
- **Member attribution**: Write operations optionally accept `?m=memberToken` for attribution without authentication.
- **CORS**: Restricted to configured browser origins; CORS is not an authorization control.
- **Receipt scan limits**: Bounded process slots, 10 admissions/60s per peer, 4096 peer keys and 10 MiB TOTAL multipart; no durable/global allowance yet.

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
