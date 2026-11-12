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

The Go API image uses a digest-pinned Distroless
`static-debian13:nonroot` runtime, with CGO disabled in production and execution
as UID/GID 65532. Go supplies DNS/user lookup and TLS without runtime libc/OpenSSL;
race/SQLite tests retain CGO. Its same-binary `--healthcheck` mode probes
the established local
HTTP health endpoint before database initialization. The API server command
and port are unchanged; see [container liveness](../backend/README.md#container-liveness)
and the [local runtime harness](../backend/README.md#static-runtime-verification).

Local Compose defaults to PostgreSQL and the API, keeping its existing project and
volume identity. Next.js is the maintained local and production viewer; the legacy
Go HTML binary, templates, Dockerfile and Compose profile have been removed. This
source retirement makes no claim about external hosting-account or DNS changes.
See [local workflow](../README.md#quickstart).
The Bash entrypoint owns exact container/process cleanup and supervises both local
clients. A Python stdlib helper owns cancellable command deadlines and terminal
handoff. Failed inventory is an error; unresolved partial ownership requires manual
inspection. See the [correction evidence](reviews/2026-11-03-local-workflow-correction.md).

### Request Flow

1. Client sends HTTP request with access token (`?t=token`)
2. Handler parses request, rejects NUL in selected access/member tokens before
   database access, and validates the token against the stored tab/bill token
   JSON mutations decode into content DTOs and validate text before service calls:
   buffered requests walk the decoded DTO; streaming requests check strings while
   binding, including the assignment binder fallback. Both reject PostgreSQL-
   unrepresentable NUL while retaining other controls and the JSON decoder's
   Unicode replacement behavior.
3. Service executes business logic
4. Repository performs database operations via GORM
5. Response returned as JSON

## Data Models

### Tab

The central grouping entity. Represents a trip or event where multiple bills are tracked.

The sketches below are abridged; `backend/pkg/models` is the source.

```go
type Tab struct {
    ID              uint         // Primary key
    Name            string       // e.g. "Beach Trip 2025"
    Description     string
    DisplayCurrency string       // Display preference; accounting stays in USD
    Bills           []Bill       // FK: Bill.TabID
    Members         []TabMember  // FK: TabMember.TabID
    TotalAmount     float64      // Computed in USD (not stored)
    NetBalances     []NetBalance // Computed (not stored)
    Finalized       bool         // Locked when true
    FinalizedAt     *time.Time
    AccessToken     string       // 64-char secure token; no expiry
}
```

### Bill

An individual expense with line items and per-person share calculations. A bill is
created standalone (`TabID` nil) and may be attached to one tab later; it cannot be
moved or detached afterwards. `LazyMode` marks a standalone item-claim bill opened at
`/b/:id`. Trips created by the older lazy flow hold their receipt as a tab bill and
stay interactive at `/t/:id`.

```go
type Bill struct {
    ID              uint
    LazyMode        bool             // Standalone item-claim bill
    TabID           *uint            // Optional: attached to a tab
    AddedByMemberID *uint            // Who added this bill
    PaidByMemberID  *uint            // Who paid it, for tab balances
    Name            string
    Subtotal        float64          // Receipt (native) currency
    Tax             float64
    TipAmount       float64
    TipPercentage   float64
    Total           float64
    CurrencyCode    string           // Receipt currency, default USD
    USDExchangeRate float64          // Frozen at creation
    USDTotal        float64          // Frozen USD value used for tab accounting
    DisplayCurrency string           // Display only; with separate display quote fields
    Date            time.Time
    PaymentMethods  []PaymentMethod  // JSONB — Venmo, Zelle, etc.
    Participants    []Person         // legacy wire view; scoped ParticipantRows persist
    Items           []BillItem       // Line items with assignments
    PersonShares    []PersonShare    // Calculated per-person totals
    AccessToken     string           // 64-char secure token; no expiry
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

Created once when a tab is finalized. New snapshots store gross allocated USD by tagged member/guest reference with a frozen display label. Historical version1 rows remain exact raw records; net payer balances and the two paid flags retain their separate meanings.

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

**Repository** — Owns authorization, lock ordering and checked commit. Consistent read-only transactions use complete explicit column shapes at every graph/preload owner. Finalization batch-projects scoped participants, frozen shares and reference closure without financial revaluation or provider calls.

## Frontend Architecture

### Flutter (Mobile)

- **State Management**: Provider pattern for unidirectional data flow
- **Local Database**: Drift ORM (SQLite) for offline bill storage and tab metadata
- **API Client**: HTTP service for backend communication. Publication is owned by
  `RecentBillsManager.saveReceipt`/`resumeReceipt`: the request is committed locally
  first, then sent once, and an unfinished save stays pending for launch or manual retry
- **Schema Migrations**: Drift schema v10

`Person` is a receipt occurrence whose equality/hash use only immutable `clientRef`.
Its optional server `participantId` and confirmed member association are separate
selectors. Copy/rename/color preserve the ref and allocation label; People/groups
remain suggestions copied into fresh occurrences. Receipt JSON has one persisted
ordered registry shared by assignment, birthday, saved-share and history readers.
Legacy name JSON remains readable with review state; it cannot establish ownership.
Imported/raw legacy share rows retain exact row IDs, labels, amounts and manual flags,
including duplicate blank labels. History cards and shared text show recorded rows or
raw assignments rather than guessed per-person zeros. Receipt JSON metadata marks the
ref-bearing representation independently of immutable wire/ack versions.
The existing calculator and frozen-USD allocator keep their arithmetic; immutable
allocation labels preserve rename-independent ties. Duplicate-label remainders use the
receipt registry ordinal rather than mutable database share-row order; imports retain
observed allocation labels by participant ID across label changes. The separate `.005` and JPY
precision contracts remain open.

`ApiService.buildBillRequest` remains the creation serializer. New saves explicitly
select wire2, declaring case-sensitive refs for duplicate/blank/Unicode labels and
omitting valid zero assignment entries while retaining zero shares. Its wire1 mode
remains for frozen compatibility fixtures; attempted old requests are never rebuilt.
`RecentBillsManager.saveReceipt`/`resumeReceipt` remains the sole publication owner.
Drift10 additively stores original wire/response versions, original ordered participant
map, receipt registry and separate current graph/revision observations. One exact-row
checkpoint stores a validated response2 map with original source authority before
sharing/attachment. Original revision0 is historical evidence. Unknown outcomes retain
the same native key locator and exact bytes/header; missing attempted keys and release
publication guards remain. No second save journal/uploader or key fallback exists.

Tab member IDs are persisted from create/join or authenticated `members/me`; cached
IDs/names never prove membership. Existing tokens recover through `members/me`, without
label rejoin. Both receipt/tab screens expose current occurrence selection, rename,
unbound/pending/confirmed states, binding requests and creator/source decisions with
revision and item timestamp checks. Stale conflicts refresh and require deliberate
retry. Attachment recovery first observes the same-tab postcondition, then reauthorizes
source/destination/member through the existing read-only attach retry before checkpoint.
A denied reauthorization or local checkpoint failure terminates that recovery pass.
Atomic fresh-self binding is unavailable in the current server/schema contract; clients
use explicit create-unbound/request/approval and never fabricate confirmation.

### Next.js (Web Viewer)

- **Rendering**: App Router with React Server Components for initial data fetch
- **Pages**: `/b/[id]` for bill viewing, `/t/[id]` for tab viewing; the static
  `(public)` group owns `/` and `/privacy-policy` at `https://billingtonapp.vercel.app`.
  Its literal site configuration, semantic policy JSX, scoped CSS and brand-only
  social image need no API, private component or browser storage. Root metadata
  remains generic/noindex; private route titles describe only the shared bill/tab
  page type without resource names or bearer data. Only public pages override indexing and add canonical/
  social metadata. Homepage-only SoftwareApplication data uses visible claims.
  Robots permits private crawling so noindex can be read; sitemap lists only the
  two public documents, without dates or resource enumeration.
- **Client Components**: LazyBillBoard, MemberList, and bill/tab breakdowns
- **Settlements**: Presentational `SettlementCard` shows names, amounts and paid status,
  directs status updates to Billington, and retains the external Venmo link. The sole
  tab-page caller has no writable browser settlement mode or mutation helper.
- **API Client**: `src/lib/api.ts` negotiates wire2 and carries participant IDs,
  current revisions, item timestamps and independent member/source proof. Browser
  participant selection is version2/bill-scoped; membership is version2/tab-scoped and
  authenticated on reopen. Old names are suggestions. Confirmed totals group by scoped
  member ID; unbound/pending occurrences remain distinct guests. Collection errors and
  nullable net/totals remain explicit review/unavailable states. Computed accounting
  advertises USD separately from display preference. Ordinary settlement cards stay
  read-only, with raw legacy snapshot/review notices.

## Key Technical Decisions

### Anonymous Tokens Instead of Accounts
Users never create accounts. Access is controlled by 64-character cryptographic tokens generated with Go's `crypto/rand.Text()`. Tab creators and members each receive unique tokens that are stored locally on their devices.

Public bill creation accepts an explicit content contract. Unkeyed requests create
independent standalone graphs; keyed requests recover the original persisted creation. One transactional attachment operation requires independent bill/tab
capabilities, resolves member attribution inside the destination, and locks tab before
bill. Same-tab retries preserve original attribution. Membership writers take the same
tab lock; standalone claims recheck `tab_id IS NULL` at their locked write boundary.
The private assignment decoder tracks field presence separately from decoded values,
including explicit null and ordered duplicates, using encoding/json. It rejects
unknown/trailing input and changes its receiver only after success. DTOs, person/share
decoders and public wire errors remain unchanged. The test-only lifecycle snapshot
keeps all nine whole-record sets while ordering rows by unique numeric id; it is not
an API projection. See [scoped evidence](reviews/2026-11-06-assignment-snapshot.md).

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
Drift10 save/resume transaction, immutable request and exact-ID checkpoints; Done,
launch/history retry and tab additions enter that owner. Its API/storage/key-store
seams expose durable publication, valuation and attachment results. No time/content
deduplication or newest-row identity lookup remains on that path. Imported tab
snapshots cannot acquire source/publication authority. Pending/referenced receipts
survive capacity handling; inability to evict safely fails the new transaction.
Remote tab imports also protect every existing and newly imported receipt in that
pass. The complete import and local tab-ID checkpoint share one transaction; a full
history or parse/checkpoint failure rolls it back without dangling IDs or a partial
balance. Capacity remains30. New durable receipts supply an insertion timestamp
instead of inheriting an old table's literal default; historical rows are not backfilled.
Save/resume rejects mismatched snapshot/wire versions before a network mutation,
without replacing the stored bytes or key. Finalized tab history reads retain their
review status and exact recorded settlement rows even when no receipt list is
available; failed reads offer an explicit retry and never imply an empty balance.
Mobile tab refresh and join persist the server's `finalized: true` in the existing
Drift flag before receipt imports; stale open responses and failed reads cannot
reopen it. Members use the same server settlement history as creators. Receipt
entry and existing-bill selection recheck saved finalization, including an already
open picker; pending attachments retain the receipt without adding it to a closed tab.
Receipt read/cache/parse failures always clear loading and withhold person totals and
finalization until a complete read succeeds. Browser join text is owned by the current
bill/tab session; participant-graph refresh only revalidates selection, while member
recovery follows tab/token changes and clears only its own authentication warning.
Only valid ready/legacy snapshots retain the existing exact-row paid control.
Mobile occurrence creation merges the typed response before selecting its ID; an
uncertain explicit retry keeps the original client reference. Browser review receipts
show raw share rows in recorded order, using exact remote row IDs or an ordered local
occurrence when absent. Their paid action requires the independent source capability;
tab/member proof and labels cannot substitute, and ordinary browser settlements stay
read-only.
Selecting a different occurrence resets payment review; rendering also requires
a validated current amount for that selected share. After a paid-marker acknowledgement, mobile and
browser keep recorded rows if the current read fails, show saved-but-unavailable
status and offer a GET-only retry. A failed read never repeats the paid mutation
or substitutes credentials; tab and settlement read errors remain separate.
Lazy claim/paid actions apply the same acknowledgement/read distinction. Denied,
stale or uncertain edits retain a deliberate read recovery path; failed recovery
reads are handled without repeating the write or rejecting the UI event promise.
Foreign values without an audit stay unavailable; frozen zero stays zero. Display
rates are temporary values and never write frozen quote columns. Versioned JPY
precision and the known local/server `.005` allocation difference remain open. See [API contracts](backend-api.md#currency-quotes)
for accepted fields, ownership, freshness and legacy compatibility; its
[currency support matrix](backend-api.md#currency-support-matrix) is the one summary
of original amounts, frozen USD valuation, display conversion and failures.
`FinalizeOnce` is the sole production finalization seam: tab capability, current creator
or memberless policy, stored-result validation, gross allocation, bounded inserts and
one checked active-state update commit together. Authorized retries read the stored
snapshot without writes/recalculation. New snapshots use tagged version2 parties and database-returned values/counts. Valid
legacy1 raw rows retry exactly, including duplicate/empty labels. Mixed/missing/invalid
evidence refuses mutation without regeneration. Wire2 preserves safe raw bills/history
and explicit null/unavailable identity or accounting projections; unsafe serialization
fails finite503. Faithful wire1 reads remain, otherwise actionable upgrade is required.
Stored historical money and labels are never inferred or rewritten.

Every attached writer uses Tab → ascending Bills → participants → ascending Items → Shares; settlement
writes use Tab → Settlement. Join/leave/settings take Tab first. Fresh tab/creator creation
is atomic. Source-share payment discovers association without locks and permits at most
one standalone-to-attached restart under the same 10-second request context. Lifecycle monetary projections
use checked cent conversion/sums and the existing bounded remainder semantics.

`bill.ReplaceAssignmentsLocked` owns single/batch share refresh for both contexts. It
batch-loads/locks/persists, preserves claim timestamps and unchanged economic share IDs,
and rejects paid percentage/component/total/ordered-item/frozen-USD changes. Paid routes
use exact scoped share IDs; flags remain editable after finalization without recalculation.
Leaving cannot delete creator, recorded payer/adder, binding/pending/approval/retained
receipt or snapshot references. Join retries cannot
turn an invalid supplied capability into replacement membership.

The server now uses scoped participant references for creation, claims, paid authority,
renames, binding generations/receipts, gross/net and snapshots. Confirmed members group
by tab/member ID; unbound/pending guests remain distinct per bill/participant. Web
net balance rows keep unique labels unchanged; colliding labels use the existing
`· member #ID` or `· receipt BILL #PARTICIPANT` display convention on a smaller
secondary line. Only rows with references wrap at narrow widths to keep amounts
and payment controls inside the card; other rows retain their existing layout. Checked
USD reads preserve explicit frozen zero and expose unavailable payer/valuation states.
The earlier positive-only USD fallback source defect is corrected; native Keychain
qualification, old-writer drain and full combined journeys remain open. Supported mobile/browser reference clients are implemented; their [synthetic journey](../mobile/test/live/README.md) is scoped functional evidence.
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

The API uses the SQL logger and sanitized database initialization errors. The logger suppresses SQL text, parameters, arbitrary messages and invalid configuration text; it emits bounded operation/table/error categories, known SQLSTATE codes, timing and row counts. Bind interpolation is disabled for logging. Unknown identifiers and error codes never pass through as text. Bill and tab request-error sinks use the same finite classification while retaining original typed errors for business and HTTP-status decisions.

### Immutable PostgreSQL Schema and Readiness

`bill-service` uses `migrations.Run` through the database initializer. One embedded
ordered registry replaces runtime AutoMigrate.
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
member/actor references. Current locked behavior validates generations and revisions.
Database defaults remain graph1/`legacy_review`; fresh wire1/2 misses construct complete
graph2/ready/revision0, with exact format1 preserved and response2 persisted only for
wire2. Existing replay hits never promote a graph. Header2 and participant_identity2
select the implemented server contract; matched clients/release adoption remain pending.
Actual old prefix1/2 readers pass against0003 after restart. Warm cached readers
returned500 immediately after additive DDL; a separate pgx control reproduced
SQLSTATE0A000 for cached `SELECT *` result-type invalidation. Drain readers before
DDL and replace connections before resuming; verify this operational exclusion
independently. Restarted read compatibility proves neither uninterrupted overlap
nor old-writer safety. Current readers use explicit complete column shapes. Local index reuse retains full reference validation and money/tie behavior; it establishes no latency recovery. The warm-reader test proves cached API reads and warm writers survive owned additive columns; see [warm-reader evidence](reviews/2026-11-09-reader-ddl.md). This
does not repair old cached binaries or authorize blind mutation retries. Production adoption remains
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
The Flutter app maintains its own Drift database for offline access and fast reads, and works without network access for local bills. A save is committed locally before any request; online publication is a separate, recorded step that can remain pending and be resumed. Release-mode keyed publication is still gated off in this source (`supportsCreationReplay`), so a release build would hold saves as pending. The public 1.4.0 binary predates this design: it uploads on Done and retries silently at launch (see the [privacy inventory](privacy.md)).

### Shared HTTP lifecycle and admission

`pkg/safehttp` owns the API binary's explicit HTTP server deadlines (5s headers, 20s
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
model copies. Name-based assignment updates use `DecodeJSONStream` instead: the
standard library's `encoding/json/v2` decoder binds the document in one pass with
the `encoding/json` compatibility options, `DecodeArrayFrom` stops at update 501,
and each assignment array is read once as a validated value. Arrays in the plain
two-member shape are bound directly; every other array goes through the same
`encoding/json` decode as before, so results do not depend on which path ran.
Decoder/admission rejection expires body-read deadlines and closes
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
- **Member attribution**: A scoped member bearer capability (`X-Member-Token` or `?m=`) authenticates current membership; it is independently rechecked under the tab lock. Labels grant no authority.
- **CORS**: Restricted to configured browser origins; CORS is not an authorization control.
- **Receipt scan limits**: Bounded process slots, 10 admissions/60s per peer, 4096 peer keys and 10 MiB TOTAL multipart; no durable/global allowance yet.
- **Lifecycle limits**: Access tokens do not expire and cannot be revoked or rotated. No route deletes a bill or a tab, and an attached bill cannot be detached; a member can only leave. Removing shared records is an operator action until `FEAT-1793644500` is built. Finalizing locks a tab's accounting; joining and paid flags stay available afterwards.

### Invite links and app handoff

Signed builds register only the custom scheme `billington://` (`Info.plist`).
`RunnerProfile.entitlements` has carried no Associated Domains entitlement since
[`5c684e8`](https://github.com/LLRHook/checksinmyhead/commit/5c684e8) (2026-09-10), so
Universal Links do not open the app, even though the viewer still serves
`/.well-known/apple-app-site-association` for `/t/*`. An `https` invite therefore opens
the web viewer. Its handoff (`AppHandoff`, `BillAppHandoff`) offers the custom scheme
and the App Store listing. An invite is not carried through a new installation: there
is no deferred link, so a person who installs the app reopens or pastes the link (the
Tabs screen accepts a pasted `/t/` link). The public 1.4.0 binary has only the pasted
link. Device evidence for these journeys is tracked by `FEAT-1793644507`.

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

## Changelog review automation

The repository's Changelog bot runs from trusted main in two GitHub Actions
workflows: pull-request lifecycle events and hourly reconciliation. Python standard
library REST clients read PR metadata and a Discord notice; PR code is never
executed by the privileged event job. One bot-owned Discord message holds the clock
and fingerprint; a PR comment mirrors its readable state. After a seven-day window,
a squash merge still requires no stop reactions, fresh green head checks, a clean
merge and a separately qualified Victor-owned credential. The built-in Actions
token cannot merge. Setup defaults to observation with merging unavailable; see
[Changelog operation and trust boundaries](../ops/changelog/README.md).
