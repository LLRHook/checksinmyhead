# Backend API Reference

Base URL: `http://localhost:8080` (development)

Bill reads accept the bill's `t` token, or the containing tab's token for a read-only bill view. Bill writes require the bill token. Tab writes may also require an `X-Member-Token` header; member attribution uses the optional `m` query parameter.

## Health

### `GET /health`

Returns readiness after successful startup schema validation and one live PostgreSQL
ledger-prefix query, bounded to one second. No authentication is required. Healthy status
and the operator-injected revision are preserved. Startup failure prevents serving.
Catalog definitions are checked at startup; health does not rescan accounting/catalogs.

**Response** `200`
```json
{ "status": "bill service - ok", "commit": "<RENDER_GIT_COMMIT or empty>" }
```

**Response** `503` for unavailable database, invalid/missing required ledger history or
unvalidated startup; database/driver details never enter the response:
```json
{ "status": "service unavailable", "commit": "<RENDER_GIT_COMMIT or empty>" }
```

The API `--healthcheck` loopback command treats HTTP 503 as failure.
See [schema startup modes](../backend/README.md#postgresql-schema-startup) for migration-only
and verify startup behavior. Registry remains exactly1,2,3. Historical defaults remain
graph1/`legacy_review`; fresh application creation explicitly constructs ready graph2.
The server implements participant-reference behavior below. Matched browser/mobile source clients now use the reference contract; independent
client/integrated acceptance, old-writer exclusion and rollout remain unqualified gates.

### `GET /api/app/version-policy`

Returns the public mobile compatibility policy. Response headers include `Cache-Control: no-store` so operators can raise the minimum without stale client caches. The mobile client fails open if the endpoint is unavailable; this is not an API authorization mechanism.

```json
{
  "minimum_supported_version": "2.0.3",
  "store_url": "https://apps.apple.com/app/id6746379502",
  "capabilities": {"bill_creation_replay": {"version": 1, "key_format": "base64url-32"}, "participant_identity": {"version": 2}}
}
```

Set `MINIMUM_SUPPORTED_APP_VERSION` on the bill service to a numeric `major.minor.patch` value only after the new release is available in the store. Invalid values fall back to `2.0.3`.

---

## Participant-reference contract

Every API request accepts at most one `X-Billington-Identity-Version: 1` or `2`;
absence means1. Empty, malformed, duplicate or unsupported values return400. This
selects representation, never authority. Responses echo the accepted version, vary on
this header/Authorization/X-Member-Token, and use private, no-store caching. CORS allows
and exposes the identity header. Invalid supplied membership always fails403, including
empty/duplicate proof; it cannot become genuinely memberless access.

| Creation request | Stored graph | Original201/replay |
|---|---|---|
| Existing matching format1 hit | Original graph1 or2 unchanged | Original eight-field kind1 builder; response columns remain NULL |
| New admissible wire1 miss | Fresh graph2/ready/revision0, unbound document-local union | Eight old fields; format1 normalization, bytes and ordering unchanged |
| New wire2 miss, keyed or unkeyed | Fresh graph2/ready/revision0 with ordered explicit refs | Kind2 exact persisted original bytes and map before checked COMMIT |

Wire2 creation keeps the wire1 bill/item/money/payment fields below, replacing identity
slots: participants contain `client_ref` and `name`; assignments contain
`participant_ref` and `percentage`; optional share projections use `participant_ref`
instead of `person_name`. Refs are unique case-sensitive ASCII `[A-Za-z0-9_-]{1,64}`,
explicitly declared, and resolved within this document only. Empty/duplicate labels are
legal; labels remain sanitized and at most30 Unicode code points. Unknown fields,
name/ref mixtures (including null), duplicate assignments/shares and dangling refs
fail400 before replay lookup/provider work. No storage ID/member/binding is input.

```json
{"name":"Dinner","subtotal":2,"total":2,"participants":[{"client_ref":"a","name":"Alex"},{"client_ref":"b","name":"Alex"}],"items":[{"name":"Meal","price":2,"assignments":[{"participant_ref":"a","percentage":50},{"participant_ref":"b","percentage":50}]}]}
```

Response2 adds only `response_version:2`, `identity_version:2`, `identity_revision:0`
and ordered `participant_map:[{"client_ref":"a","participant_id":17},…]` to the eight
original fields. It freezes the actual share URL and complete original JSON (≤65536
bytes). Winner, losing concurrent create and later same-key replay return those exact
bytes after checked commit, even after rename/attach/paid/finalization/config changes.
A known format1/2 conflict is409; missing/corrupt/unknown stored evidence is503
creation_unavailable. Established hits use one indexed SELECT, no transaction/writes,
providers or current-child lookup. An uncertain commit is never acknowledged; recover
with the same key/original content. New wire1 translation occurs only on a miss; an
ambiguous Unicode case-fold mapping requires409 client_upgrade_required without
invalidating an admissible historical hit. New people/participations are always fresh.

Without a member header, malformed query encoding is invalid supplied member proof,
including a malformed `m`; it never falls back to a new join. A valid member header
retains its existing precedence over query proof.

Wire2 authenticated GET returns stored `identity_version`, `identity_state`,
`identity_revision`, plus derived `identity_review_status` and
`accounting_review_status`. Allocation status is `available` only when the checked
frozen USD share owner accepts the saved shares. Invalid references give
`identity_review_required`; invalid saved money gives `accounting_review_required`.
Recorded bill/frozen totals and safe raw shares are retained without rewriting them.
Participants expose scoped `participant_id`, `bill_id`,
`client_ref`, `label`, location, `binding_state` (unbound/pending/confirmed), current
member/pending IDs, request generation and approval facts. Assignment/share rows expose
`identity_version`, `participant_id` and current `label`; historical `person_name`
is retained raw content. `viewer_member_id` is null without membership proof and comes
only from valid scoped proof. Reads use bounded read-only consistent transactions.
Source/member tokens, creation receipt/fingerprint and private last-decision fields
are absent. Invalid ready references produce explicit review without resolving a
cross-scope label or hiding independently safe raw rows.

New participant routes require header2. All bodies are strict, at most4KiB:

| Route | Body | Required current authority |
|---|---|---|
| `POST /api/bills/:id/participants` | `client_ref,name,expected_revision` | Standalone source |
| `PATCH /api/bills/:id/participants/:participantId` | `name,expected_revision` | Standalone source |
| `POST /api/tabs/:id/bills/:billId/participants` | `client_ref,name,expected_revision` | Destination and current member, or genuine memberless destination |
| `PATCH /api/tabs/:id/bills/:billId/participants/:participantId` | `name,expected_revision,bill_token?` | Current creator/bound-self, or independent source+destination/current member; source+destination for genuine memberless tabs |
| `POST …/participants/:participantId/binding-request` | `expected_revision` | Own current tab member; target is derived from proof |
| `PUT …/participants/:participantId/binding` | `expected_revision,request_revision,member_id,decision,bill_token?` | Current creator or independent source+destination/current member |

Mobile and browser serializers use these operation-specific fields. A filled source
field is omitted from create, binding-request and standalone bodies; only attached
rename/decision bodies may carry `bill_token`. Destination and member proofs remain
independent headers and never fall back to that source field.

Successful participant commands return200 `{participant:{…},identity_revision:N}`.
Actual additions/requests/decisions require active ready/unpaid eligibility; maximum100
participants. A member cannot request another participation while already bound/pending
on this bill. Pending grants no paid authority. Approve/reject must address the exact
persisted request generation/target; no rebind or pending overwrite. Actual label rename
is allowed while paid-active, preserving all economics, immutable allocation labels,
ordinals, claim times and flags. It cannot alter frozen snapshot labels.

`GET /api/tabs/:id/members/me` and `PATCH` with strict `{display_name:…}` require current
scoped membership and return `member_id,tab_id,display_name,role` without a token. Rename
is ID-based, allows an empty sanitized label ≤30 code points and remains valid finalized;
same label is a no-op, otherwise last-write-wins. It does not change bill revision.

Bill revisions are checked int64 and advance once for a changed participant/allocation
transaction or first attachment. No initial-graph, paid, finalize or member-rename bump.
No overflow. Existing item timestamps/paid/finalized/location guards remain. Only these
fully reauthorized read-only exceptions accept a stale revision:

- Same participant client_ref and original allocation label returns that original ID's
  current state, even if renamed/full/paid/finalized; changed original content conflicts.
- Same-label rename accepts current or exactly one-behind revision as a satisfied
  postcondition; it creates no historical receipt.
- Own pending request accepts current revision, or exactly one-behind only when its
  persisted pending generation equals current revision.
- A binding decision retry matches retained target/generation/decision/actor and result
  revision exactly, with expected exactly one-behind. Current proof is still required;
  its sufficient mode may change without rewriting original kind/time, including after
  paid/finalized state. A later revision/replaced receipt makes it stale.
- Same-tab attachment reauthorizes independent source/destination/current member and
  preserves attribution/times, including after later revision, paid or finalized state.

Other stale revisions return409 identity_revision_conflict. Actual legacy graph1
identity mutations require409 identity_review_required; name-only claims on ready
rows require409 client_upgrade_required. Header1 preserves representable creation,
reads, attachment, settings/join, independent source-paid and exact raw legacy
settlement behavior. Ambiguous/unavailable wire1 projections require actionable
client_upgrade_required. No name grants ownership, grouping or paid permission.

## Bills

### `POST /api/bills`

Create a **standalone** bill from content. Attach it to a tab separately using
its returned source-bill token. Without a key every request is independent, including
identical content; a different key also represents a separate receipt.

Optionally supply exactly one application-visible `Idempotency-Key`: 43 canonical,
unpadded base64url characters encoding 32 random bytes. Present empty, duplicate
(case-insensitive name cardinality), comma/list, padded, noncanonical or internal
whitespace/control values return `400`. Validation runs after Go's standard HTTP
parser; leading/trailing wire whitespace and some complete-value folds can become
indistinguishable canonical values. There is no custom wire parser; the independent identity header selects the content version below.

The service validates the strict DTO and normalized content before replay lookup.
Matching key/content returns the same persisted `201` identity, source token and
frozen USD quote, including after claim, attach, paid or finalized transitions.
Established replay uses a bounded indexed scalar read without provider calls,
financial derivation or graph writes. Concurrent initial misses may each quote and
derive; one parent and its child batches commit. Different admissible content returns
`409 {"error":"creation conflict","code":"creation_conflict"}` without disclosing
an existing capability. Unknown/corrupt stored fingerprint formats or an uncertain
commit return finite `503` with `code: creation_unavailable` when a response is possible.
Recover by retrying the SAME key and original content; no automatic replacement key
or keyed-to-unkeyed fallback. Creation responses carry `Cache-Control: private, no-store`.

The key digest, immutable ordered-content fingerprint and internal format version are
private. Format1 retains identity-domain1/accounting1 bytes; format2 uses reference
identity-domain2/accounting1. Graph and response versions are independent. Wire2 also
stores its exact original bounded response; ordinary reads never disclose it. Ordered
arrays and repeated lines remain significant.
The public capability hint is neither authentication nor evidence that all old writers
are excluded. Keyed public clients require replay-capable server floors and verified
old-writer drain. Keep replay state on rollback. Before any future deletion or token
revocation removes receipt identity, add irreversible tombstones and revoke recovery
with source authority so an old key cannot resurrect a deleted receipt.

**Request Body**
```json
{
  "name": "Dinner",
  "lazy_mode": false,
  "subtotal": 100,
  "tax": 10,
  "tip_amount": 18,
  "tip_percentage": 18,
  "total": 128,
  "currency_code": "USD",
  "participants": [{"name": "Alice"}, {"name": "Bob"}],
  "items": [{
    "name": "Dinner",
    "price": 100,
    "assignments": [
      {"person_name": "Alice", "percentage": 50},
      {"person_name": "Bob", "percentage": 50}
    ]
  }],
  "person_shares": [
    {
      "person_name": "Alice",
      "items": [{"name": "Dinner", "amount": 50, "is_shared": true}],
      "subtotal": 50,
      "tax_share": 5,
      "tip_share": 9,
      "total": 64
    },
    {
      "person_name": "Bob",
      "items": [{"name": "Dinner", "amount": 50, "is_shared": true}],
      "subtotal": 50,
      "tax_share": 5,
      "tip_share": 9,
      "total": 64
    }
  ],
  "payment_methods": [{"name": "Venmo", "identifier": "@alice"}]
}
```

Only these fields are accepted. Unknown or server-owned fields at any nesting level
return `400`, including fields supplied as `null` or zero.

| Level | Allowed fields |
|---|---|
| Bill | `name`, `lazy_mode`, `subtotal`, `tax`, `tip_amount`, `tip_percentage`, `total`, `currency_code`, `display_currency`, `participants`, `items`, `person_shares`, `payment_methods` |
| Participant | `name` |
| Item | `name`, `price`, `assignments` |
| Assignment | `person_name`, `percentage` |
| Legacy share projection | `person_name`, `items`, `subtotal`, `tax_share`, `tip_share`, `total` |
| Share item detail | `name`, `amount`, `is_shared` |
| Payment method | `name`, `identifier` |

`name`, `subtotal` and `total` are required and cannot be null; item prices are required
when items are supplied. Tax/tip default to zero, `lazy_mode` to false, receipt currency
to USD and display currency to receipt currency. Receipt currencies are USD EUR GBP
CAD JPY MXN PEN AUD BRL CNY INR CHF. Display codes are normalized three-letter ASCII
codes whose available pairs are provider-defined, including ZAR independently of the
receipt policy. A failed display quote returns `503` without saving. IDs, foreign keys, tab/member/payer
associations, paid flags, tokens, dates/timestamps and derived exchange-rate fields are
never caller input. The server generates fresh persistence identities, dates and tokens.

All accounting values must be finite and bounded. Receipt totals and person obligations
must be nonnegative. Total must equal subtotal + tax + tip, and itemized subtotal must
equal the signed item sum, within 0.01 plus floating-point tolerance. Negative discount
lines/details are allowed. Custom tip amounts need not match percentage metadata.
The assigned subtotal cannot exceed the receipt subtotal except for relative
floating-point noise (`subtotal × 1e-9`); the absolute receipt tolerance never enlarges
the denominator used to apportion charges. Raw per-person components and aggregate
obligations are checked before cent conversion/allocation. Rounded aggregate obligations
are also bounded by the receipt total within the accounting tolerance. Unsafe derived
arithmetic is rejected rather than clamped or replaced with a zero share.
Names are trimmed/sanitized; duplicate normalized participant/share names or duplicate
people on one item are rejected. Assignment percentages must be in `(0,100]` and sum to
at most `100 + 1e-9`.

The mobile creation builder omits only valid exactly-zero assignment entries; it keeps
the participants and zero-obligation share rows. Negative, non-finite, individually
over-100 or overallocated percentages produce an actionable client validation error
before publication. Empty and partial lazy claims remain supported. Receipt participant
entry and upload use the 30-code-point bound, including recent people and groups;
historical labels remain readable and are never truncated or rewritten. Tab join/member
validation has its own contract and is not changed by this receipt-entry check.
Saved-history publication checks the raw stored assignment values before display
reconstruction can omit nonpositive entries. Receipt-name preflight uses Go's Unicode
White_Space trimming after tag removal: U+FEFF is retained and counts toward the limit.

Share projections are optional compatibility input, validated against item assignments
and the mobile formulas; raw fractional tax/tip and cent-rounded totals are supported.
The server derives stored shares and non-null item breakdowns using the existing cent
allocation. Remainder distribution is bounded by participant count and retains the
existing most-recent-claim, then alphabetical-name order among eligible shares.
Negative adjustments debit only positive cent balances; insufficient balances fail
instead of creating negative obligations. Zero-share participants and repeated item
descriptions are preserved. The frozen USD share audit accepts the same accounting
tolerance as creation: a rounded allocation just above the raw total uses the frozen
receipt target, while genuinely partial claims are never scaled to the full receipt.
The persistence preflight checks both the frozen receipt and its share allocation.
Historical saved uploads with no items or no assignments can supply zero-component
share projections whose totals cover the receipt; the server derives their breakdowns.

Set `lazy_mode` to true for a standalone item-claim bill at `/b/:id`. Participants/shares
may be empty, and partial claims retain tax/tip proportions against the full receipt
subtotal. Creation never creates or selects a tab.

Limits: 1 MiB JSON body with one document; 500 items; 100 participants/shares and
distinct person names; 100 assignments per item and 5,000 overall; 10 payment methods.
Person names allow 30 Unicode code points, bill/item names 255, payment names 50 and
identifiers 256. Individual monetary magnitudes and absolute item-price sum are limited
to 1e9 native units, as are derived per-person and aggregate obligations. Cent conversions
must be representable. Invalid input returns `400` before quoting or persistence.

**Response** `201`
```json
{
  "bill_id": 1,
  "access_token": "abc123...",
  "share_url": "https://billington.app/b/1?t=abc123...",
  "currency_code": "USD",
  "usd_exchange_rate": 1,
  "exchange_rate_date": "",
  "exchange_rate_source": "native-usd",
  "usd_total": 128
}
```

For supported non-USD bills the service freezes a verified daily rate/date/source.
A failed or invalid provider quote returns `503` without saving. Original/frozen
amounts and the frozen USD quote keep separate ownership from display conversion.
Bill reads omit the source access token.

### Currency quotes

One required Frankfurter v2 pair client supplies new frozen USD values, temporary
preview and daily indicative display conversion. New quotes require the requested
base/quote, positive finite rate, adapter source `frankfurter-v2-blended` and strict
`YYYY-MM-DD` provider observation date. UTC age may be at most seven calendar days,
with at most one day ahead. These are application freshness limits, not a provider SLA.
Accepted rate/day are preserved exactly; reads/attachment/display changes never
refetch or freshness-reject historical frozen quotes. Native USD has rate 1 and source
`native-usd`, with an empty date (no invented market observation).

Creation uses at most two distinct foreign pairs under one five-second provider
budget, with one attempt per pair and caller cancellation. A requested USD display
reuses the operation's frozen pair. There is no backend application rate cache or
fallback provider. The 64 KiB upstream limit and finite errors prevent unbounded
response/error handling. Upstream 429/503 returns public 503 with a validated
`Retry-After` delay/date when supplied; callers must honor it before retrying.

`currency_code`/original amounts are native receipt values. `usd_exchange_rate`,
`usd_total`, `exchange_rate_date` and `exchange_rate_source` are frozen USD fields.
`exchange_rate`/`display_total` describe the selected display conversion and never
write those frozen date/source fields. Migration 0002 stores independent nullable
`display_rate_date`, `display_rate_source`, `display_rate_retrieved_at` fields on reads.
Foreign display retains its own exact observation day/source and UTC microsecond
retrieval receipt. A USD display reuses the accepted frozen pair. Native display has
`same_currency` source and no invented market/retrieval time. Historical null provenance
stays unknown; reads never refetch, reprice or freshness-revalidate saved values.
A valid frozen zero remains zero. Missing foreign data never means identity or zero.
Tab summaries and settlement allocation validate the same saved USD audit. An unset
legacy USD value may use native identity in memory; a display/native foreign amount
never substitutes for unavailable USD. Invalid or inconsistent frozen evidence makes
the authorized tab summary require accounting review, without rewriting saved rows.
Current accounting precision, including fractional legacy JPY, is unchanged; the
versioned whole-yen accounting step remains required follow-up.

### `GET /api/currency/rate?from=USD&to=PEN`

Public display conversion for provider-defined pairs. Response `200` keeps fields
`from`, `to`, **`rate`**, `source`, `updated_at`. For foreign pairs, `updated_at` is
the provider observation day at UTC midnight, not retrieval time. Same-currency
identity returns rate 1/source `same_currency`; its `updated_at` is request time
and does not represent a market observation. Invalid/unavailable pairs return 503
`{"error":"exchange rates are temporarily unavailable"}`. This endpoint does not
freeze or change any saved receipt. The mobile decoder accepts finite positive JSON
numbers from `rate`, including integer encodings, without a rate-1 fallback.

New mobile wire2 save operations persist their ordered creation request, original wire/header version, snapshot version,
nonsecret operation/key locator, native amounts and optional attachment intent in
Drift10 before publication. They commit an attempted marker before their one keyed
POST and checkpoint the eight persisted201 authority fields plus the strictly validated
ordered response2 participant map to the exact row before sharing or attachment.
Response2/identity2/revision0 and exact unique positive map IDs/ordered declared refs
are required. Current identity revisions come from a fresh authenticated GET. Old
attempted snapshot1 rows retain original bytes/key/absent-header semantics and expect
the original eight-field response; they are never converted to wire2 on resume. A lost/invalid response or checkpoint failure retains the
same recovery capability and snapshot. Missing keys after an attempt block further
publication; imports/ambiguous old history are never automatic create work.

Client upgrade policy may fail open for app access; creation replay preflight fails
closed. The source additionally disables keyed publication in release mode pending
separate source-floor, old-writer-drain and native qualification. A version-policy
response cannot establish drain or authorize rollback to a replay-ignorant server.

### `GET /api/exchange-rates/:currency`

Preview the latest verified daily conversion from the selected currency to USD before saving a receipt.
Supported receipt currencies are `USD EUR GBP CAD JPY MXN PEN AUD BRL CNY INR CHF`.

**Response** `200`
```json
{
  "date": "2026-08-29",
  "base": "EUR",
  "quote": "USD",
  "rate": 1.1652,
  "source": "frankfurter-v2-blended"
}
```

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 400 | `{"error": "unsupported currency code"}` | Currency is not supported by the approved receipt policy |
| 503 | `{"error": "daily exchange rate is unavailable; retry or use USD"}` | No verified daily quote is available; no conversion should be saved |

### `GET /api/bills/:id?t=token`

Get a bill by ID.

**Response** `200` — Full bill object with items, participants, person_shares, payment_methods.

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 403 | `{"error": "token mismatch"}` | Invalid access token |
| 404 | `{"error": "bill not found"}` | Bill does not exist |

### Reference claims (single and batch)

With header2, single claims use `{expected_revision,expected_updated_at?,assignments:
[{participant_id,percentage}]}`. Standalone lazy route:
`PATCH /api/bills/:id/items/:itemId/assignments`; attached route:
`PATCH /api/tabs/:id/bills/:billId/items/:itemId/assignments`. Batch siblings replace
`assignments` with `updates:[{item_id,expected_updated_at?,assignments:[…]}]` under
`PATCH /api/bills/:id/assignments` or `/api/tabs/:id/bills/:billId/assignments`.
An empty assignments array releases unpaid claims; percentages remain `(0,100]`,
unique within each item and total ≤100+1e-9. IDs must belong to this bill. Mixed name/
reference or unknown wire2 fields fail400. All siblings use the same replacement owner.
Single success is200 status ok; standalone batch success returns the current selected representation.
The attached tab batch endpoint returns200 `{status:"ok"}`. Mobile treats it as an
acknowledgement, then reads the current tab with destination/member proof and selects
the exact bill. A failed read offers read-only retry and cannot produce a zero payment
total or automatically repeat the committed PATCH.

The old wire1 content decoder still ignores unknown fields and retains standard known-
field duplicate/null semantics; ignored paid/association/reference fields never enter
the command. After decoding, a real name-only mutation receives the actionable upgrade
response. This compatibility does not relax strict fresh creation or strict wire2 DTOs.

### Receipt and tab mutation policy

Tab item assignment (single/batch) checks current membership, active state, exact
bill/item scope and expected timestamps in the transaction. Standalone claims retain
source-bill proof and locked `tab_id IS NULL`; attaching first makes a stale claim fail.
Batches support at most 500 items/100 assignments per item, within a 4 MiB body.
They preserve claim priority and unchanged economic share IDs. Changing a paid share's
percentages, components, total, ordered item details or frozen USD cents returns `409`
and rolls back the complete batch. Changed/removed shares cannot be paid via stale IDs.

Source-bill `PATCH /api/bills/:id/shares/:shareId` uses the exact bill/share IDs and
bill capability; a tab token cannot substitute. Attached source payment locks tab
before bill and is allowed after finalization. Tab-share payment requires a ready share/participant whose confirmed member ID equals
the current actor ID, including equal-flag retries. Unbound, pending, same-label other
members and creator overrides are denied403; legacy identity needs review409.
Both payment routes change only the selected receipt paid flag, with scoped `404` for
stale IDs. Generic `503`/`500` responses never expose database messages.

All attached writers use Tab → Bills by ID → participants → Items by ID → Shares; settlement writes
use Tab → Settlement. Membership/settings take Tab first. Mutations use the request
context with a 10-second maximum (earlier caller deadlines win). This protocol requires
all deployed writers to cooperate. It does not establish rollout or signed-client proof.

---

## HTTP resource policy

The API binary uses read-header/read/write/idle timeouts of 5/20/50/60 seconds
and a 32 KiB `MaxHeaderBytes` setting. Signal cancellation reaches request contexts;
shutdown waits at most 25 seconds, then closes connections. A write deadline alone
does not cancel handler work. Recovery returns a generic JSON 500 before response
commitment, and aborts partial/disconnected responses without appending a false 500.
Process diagnostics never print raw panic values, requests, headers, bodies or stacks.

All JSON mutation routes share eight in-flight slots per process, independently of
`Content-Type`. There is no waiting queue: saturation returns 503 with `Retry-After: 1`.
Reads and health bypass the gate. CORS exposes `Retry-After` to permitted origins.
For a rejected request with a body, decoder/admission rejection expires its read
deadline. HTTP/1 responses also close the connection so transport cleanup cannot
wait for the unread remainder.
HTTP/2 uses a stream read deadline without a `Connection` header. Complete valid
requests retain ordinary keep-alive behavior.
JSON bodies must contain exactly one document, including trailing whitespace within
the byte cap. Creation and attachment retain strict unknown-field rejection; other
existing DTOs continue ignoring unknown fields. Standalone paid updates and attachment
are capped at 4 KiB; other existing JSON mutations at 4 MiB. Existing byte excess
returns 400 for compatibility. Assignment batches reject over 500 updates, 100
assignments per item or 50,000 assignments in total before transforming DTOs.

`TRUSTED_PROXY_CIDRS` defaults to empty (trust no forwarding proxy). Supplied values
must be at most 32 canonical network CIDRs in 2 KiB, separated by commas, with no
empty entries, hostnames, host-bit prefixes, mapped IPv4 CIDRs or `/0`. Invalid
configuration fails startup with a finite error. Only `X-Forwarded-For` is considered,
using Gin's right-to-left trusted-hop policy with socket fallback. Valid IP tokens
are canonicalized independently, including mapped IPv4; invalid/empty tokens remain
in place. Gin falls back to the socket if its trust walk reaches an invalid token;
an unused invalid left prefix does not disable a selected valid suffix's normalization.
`X-Real-IP` and platform/AppEngine headers are ignored.
A proxy left unconfigured may share one peer identity across its users. Source policy
does not establish hosted topology or verify a production allowlist.

## Tabs

### `POST /api/tabs`

Create a new tab with at most 16 KiB of JSON, including trailing whitespace. After
HTML stripping and whitespace trimming, name/description/optional creator name may
contain at most 255/4096/30 Unicode code points. Excess is rejected without truncation:
byte excess returns 413, malformed/trailing/text excess returns 400. Name and creator
remain optional; omitted creator leaves the tab memberless, and the display-currency
default remains USD. Unknown fields, including privileged association graphs, are ignored.

When supplied, the initial creator and tab commit together; a creator insertion failure leaves no tab. Creator membership cannot be added to an existing tab through join.

**Request Body**
```json
{
  "name": "Beach Trip 2025",
  "description": "Summer vacation expenses",
  "creator_display_name": "Alice"
}
```

**Response** `201`
```json
{
  "tab_id": 1,
  "access_token": "xyz789...",
  "share_url": "https://billington.app/t/1?t=xyz789...",
  "member_token": "mem456...",
  "member_id": 1
}
```

`member_token` and `member_id` are only included when `creator_display_name` is provided.

### `GET /api/tabs/:id?t=token`

Header2 returns raw bills/current reference views, accounting_currency:"USD", nullable
`total_amount`, `total_status`, nullable `net_balances`, `net_balance_status` and scoped
`viewer_member_id`. Missing/dangling/cross-tab payer or bad reference evidence yields
identity_review_required and null net, preserving safe raw bills/frozen totals. Invalid
valuation yields accounting_review_required; unsafe total is also null. Available/no
transfers is an actual empty array, never a swallowed calculation error. Display
currency is a preference; it never relabels computed USD or triggers a quote on read.


Get a tab with all bills, items, assignments, person shares, and members.

**Response** `200` — Full tab object. `total_amount` sums validated frozen USD cents,
including genuine zero values, independently of each bill's display currency.

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 403 | `{"error": "token mismatch"}` | Invalid access token |
| 404 | `{"error": "tab not found"}` | Tab does not exist |
| 409 | `client_upgrade_required` | Wire1 cannot faithfully represent identity or unavailable computation; use header2 review/null projections |

Access is checked before returning review data. Stored receipts
and accepted quotes remain unchanged; no provider call repairs historical data.

### `PATCH /api/tabs/:id?t=token`

Update tab name, description or `display_currency`, with current creator or genuinely memberless authority checked under the tab lock. Blocked if finalized. Omitted/empty name and description retain their existing values. Only these settings can change; receipt quotes remain frozen.

**Request Body**
```json
{
  "name": "Updated Name",
  "description": "Updated description"
}
```

**Response** `200`
```json
{ "status": "ok" }
```

### `POST /api/tabs/:id/bills?t=token&m=memberToken`

Attach an existing standalone bill using **independent** source and destination
proof. Supply the destination token through `Authorization: Bearer <tab token>` or
the existing `?t=` link, and the source token in the body. A destination token never
substitutes for the source token. Opaque source-token bytes are matched unchanged.

**Request Body** (one JSON document, maximum 4 KiB)
```json
{ "bill_id": 5, "bill_token": "source-bill-token" }
```

Once a tab has members, a matching member token within that tab is required through
`X-Member-Token` or `?m=`. The authenticated member supplies both added-by and paid-by
attribution. Memberless legacy tabs still accept the tab token without a member token,
but require source proof; a supplied invalid member token fails.

Authorization, finalized-state check and attachment execute in one transaction using
destination-tab then source-bill row locks. Same-tab retries revalidate all
credentials and succeed without changing attribution, timestamps or quote metadata,
including after later revision, payment or finalization. Header2 first attachment also
requires expected_revision. First attachment updates participant locations atomically
and advances bill revision once without binding anyone.
A bill already in another tab cannot be moved. A failed attachment leaves its source
bill available through the original bill token.

**Response** `200`
```json
{ "status": "ok" }
```

| Status | Meaning |
|---|---|
| 400 | Malformed/oversized/trailing/unknown JSON, nonpositive bill ID, blank source token, or finalized destination |
| 403 | Missing/wrong destination token, missing required member, or wrong/cross-tab member token |
| 404 | Generic `source bill unavailable`: missing source, wrong/another source token, or source attached elsewhere |
| 200 | Authorized first attachment or fully reauthorized same-tab retry |

The existing token API uses `403` for failed capabilities. Errors never echo tokens,
source content or SQL. Attachment participates in the tab-root protocol shared with
finalization and all competing attached writes.

---

## Finalization & Settlements

### `POST /api/tabs/:id/finalize?t=token&m=memberToken`

Finalize once in one authorized Read Committed transaction: lock the tab, resolve
current creator or genuinely memberless authority, read persisted accounting/shares,
insert gross USD settlements and mark finalized. A supplied invalid member token
fails even on a memberless tab. It reads reference closure and frozen allocations in
batches, with no quote lookup or financial revaluation.

An authorized repeat returns the stored snapshot, ordered by `amount DESC, id ASC`,
with the same IDs, amounts, creation/finalization times and current settlement paid
flags. A lost successful response can be retried. The operation returns success only
after commit. Gross allocations, receipt-share paid flags, settlement paid flags and
net payer balances are distinct; neither flag proves an external transfer.

Foreign accounting needs valid frozen rate/date/source/total evidence. Legitimate
frozen USD zero and known legacy USD identity are supported without backfill.
No bills or no allocated share rows leaves the tab active; explicit zero participant
rows count as allocations. New snapshots are uniformly version2: confirmed parties
group by (tab_id,member_id); pending/unbound guests remain distinct (bill_id,participant_id).
Duplicate/empty labels are legal. Frozen USD gross AND net use the same checked money
kernel; local ties use last claim then immutable lowercase allocation label/ordinal,
USD ties raw allocation label/ordinal. Rename and paid flags do not change cents.
The checked USD allocator reuses its validated participant index within each call;
complete reference/receipt validation still precedes a zero-amount return.

**Response** `200` — Array of persisted gross USD settlements (first transition or retry).
```json
[
  { "id": 1, "tab_id": 1, "person_name": "Alice", "amount": 90.00, "paid": false },
  { "id": 2, "tab_id": 1, "person_name": "Bob", "amount": 60.00, "paid": false }
]
```

**Errors**

| Status | Meaning |
|---|---|
| 400 | `no_bills` or `no_allocation`; the tab remains active |
| 403 | Missing/wrong tab capability, invalid supplied member token, or current non-creator |
| 409 | identity/accounting review: unresolved or inconsistent graph, orphan/missing/mixed invalid snapshot, invalid frozen evidence or unsafe money |
| 503 | Generic temporary unavailability; retry |
| 500 | Generic unexpected failure; no database text |

Review errors preserve stored history. Authorized reads remain available. Production
adoption and exclusion of old writers still need separate deployment evidence.

### `GET /api/tabs/:id/settlements?t=token`

Header1 returns the exact valid raw array below, including legitimate duplicate/blank
legacy labels. Header2 returns `{settlements:[…],identity_review_status,
accounting_currency:"USD",viewer_member_id}`. Rows include snapshot_version, raw label,
amount/flag/time and a tagged frozen party for valid snapshot2. Nonempty valid legacy1
history says legacy_identity_review_required and has null party; mixed/invalid/missing
evidence says identity_review_required, retains safely serializable raw rows and fails
closed on retry/paid mutation. No snapshot regeneration or inferred ownership occurs.
New finalize header2 uses this same envelope. Safe raw data that cannot be serialized
returns finite503 representation_unavailable before any successful JSON header.

**Response** `200`
```json
[
  { "id": 1, "tab_id": 1, "person_name": "Alice", "amount": 90.00, "paid": false, "created_at": "..." }
]
```

### `PATCH /api/tabs/:id/settlements/:settlementId?t=token`

Set the selected finalized snapshot's paid flag using a current same-tab member,
or genuinely memberless authority. Repeating the same boolean succeeds without a
write. Active orphan results require `409 accounting_review_required`; a settlement
outside this finalized tab returns `404`. Amounts and receipt-share flags do not change.

**Request Body**
```json
{ "paid": true }
```

**Response** `200`
```json
{ "status": "ok" }
```

---

## Members

### `POST /api/tabs/:id/join?t=token`

Join serializes with the tab and remains allowed after finalization for access and
payment recovery. A valid supplied same-tab member token returns that membership
without writing (`200`); an invalid supplied token returns `403` and cannot create a
replacement. Ordinary new joining returns `201` and grants no accounting reassignment.
Leaving cannot remove the creator (`400`) or any member whose recorded ID appears as
bill payer/adder, current/pending binding, approver, retained receipt target/actor or
snapshot (`409 member_referenced`), including historical cross-tab references.
Unreferenced members may leave. No name-based recovery or provenance repair occurs.

Join a tab as a member. Returns a member token for future attribution.

**Request Body**
```json
{ "display_name": "Bob" }
```

**Response** `201`
```json
{
  "member_id": 2,
  "member_token": "mem789...",
  "display_name": "Bob",
  "role": "member"
}
```

**Errors**
- `400` if `display_name` is empty or exceeds 30 characters.

### `GET /api/tabs/:id/members?t=token`

List all members of a tab.

**Response** `200`
```json
[
  { "id": 1, "tab_id": 1, "display_name": "Alice", "role": "creator", "joined_at": "..." },
  { "id": 2, "tab_id": 1, "display_name": "Bob", "role": "member", "joined_at": "..." }
]
```

---

## Receipt Parsing

### `POST /api/receipts/parse`

Parse a receipt image using Anthropic's Claude Messages API. No user authentication is required. The image is processed for the request and is not saved in Billington's database. Admission is limited to 10 starts per rolling 60 seconds per normalized client IP, including admitted invalid images. A process has 2 nonwaiting slots by default (`OCR_MAX_INFLIGHT=1–8`), held from before upload allocation through provider parsing. Denials do not charge a peer or extend its expiry. At most 4096 live peer keys are retained; a full table rejects new peers with 503/Retry-After 15 while existing peers remain eligible. These limits multiply across replicas; durable/global allowance is deferred.

**Request**: Multipart form data with `image` field.

- Max TOTAL multipart size: 10 MiB (boundaries included), streamed without disk/pixel decode
- At most 32 parts, 16 KiB/64 parsed headers per part; duplicate image fields return 400
- Receipt operation 40s from before upload; provider 30s; earlier caller/socket deadlines win
- Accepted MIME types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`

**Response** `200`
```json
{
  "vendor": "Olive Garden",
  "currency_code": "USD",
  "currency_symbol": "$",
  "currency_confidence": 0.98,
  "items": [
    { "name": "Chicken Alfredo", "price": 18.99, "quantity": 1 },
    { "name": "Breadsticks", "price": 0.00, "quantity": 1 }
  ],
  "subtotal": 18.99,
  "tax": 1.52,
  "tip": 0.00,
  "total": 20.51
}
```

**Fields**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `vendor` | string | No | Store/restaurant name |
| `currency_code` | string | No | ISO 4217 currency code when detected |
| `currency_symbol` | string | No | Printed currency symbol when detected |
| `currency_confidence` | number | No | Model confidence for detected currency |
| `items` | array | Yes | Always present (may be empty) |
| `items[].name` | string | Yes | Cleaned to Title Case |
| `items[].price` | number | Yes | Can be negative for discounts |
| `items[].quantity` | number | Yes | Defaults to 1 |
| `subtotal` | number | No | Omitted if not readable |
| `tax` | number | No | Omitted if not readable |
| `tip` | number | No | Omitted if not readable |
| `total` | number | No | Omitted if not readable |

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 400 | `{"error": "image file required"}` | Missing, duplicate or malformed image field |
| 400 | `{"error": "unsupported image type: ..."}` | Invalid MIME type |
| 400 | `{"error":"invalid client address","code":"invalid_peer"}` | Invalid normalized peer |
| 413 | Friendly error with `code: image_too_large` | Multipart/header/part excess or upstream 413 |
| 429 | `{"error": "Too many scans. Please wait a moment and try again.", "code": "rate_limited"}` | Too many requests from this IP |
| 503 | Friendly error with `auth_failed`, `overloaded` or `provider_down` | Credentials, process/provider capacity, redirect, transport/deadline or upstream failure |
| 422 | Friendly error with `invalid_request` or `bad_response` | Upstream 400, or invalid/oversized success |

The fixed HTTPS endpoint uses verified TLS, a bounded private HTTP/1 pool and one
nonreplayable POST per operation. Redirects fail; no Location/error content is
returned or logged. DNS, serial numeric TCP/TLS setup, final request Flush and
response/cancellation cleanup are joined before admission release. Private Go DNS
preserves hosts/search/UDP/TCP policy; one provider TCP socket per reservation
excludes DNS/address-selection sockets. Serial dialing exchanges Happy Eyeballs
latency for this ownership bound. Healthy idle connections reuse; selected dirty or
stale idle connections fail finitely without redial/retry, including conservative
refusal after legitimate TLS control traffic. Manual retry is a separate operation.
Deployment DNS/address-family/roots compatibility remains separately qualified.
Response headers total at most 32 KiB across up to four informational responses;
TLS is 1.2+ and HTTP/1.1 only. Decoded success reads
are cap+1 at 2 MiB irrespective of declared length/compression. Receipt text is
512 KiB. Before typed envelopes/items allocate: depth 16, 16,384 tokens, arrays
512, content 16 and items 500. Vendor/item names are at most 255 codepoints;
symbols 16; currency is absent/null or three ASCII letters; confidence is finite
[0,1]; money is finite with magnitude at most 1e9. Checked expansion
`sum(max(1, quantity)) <= 500` rejects excess/overflow without partial results.
Null fields, signed discounts, repeated lines, code fences and empty items remain.
No money/JPY/currency-confirmation policy changes follow from these guards.

Transient responses expose `Retry-After` through existing CORS: bounded seconds or
HTTP date normalize to 1–86400 seconds; invalid/missing transient hints use 60.
Valid longer waits omit the header, requiring manual retry; they are never shortened.
There is no automatic rescan. A disconnected request gets no new application response;
a still-connected deadline can return 503. Provider acceptance of all admitted
formats/sizes is unverified; no silent resizing/transcoding is performed here.

**Environment**: Backend-only `ANTHROPIC_API_KEY` is required to register the route.
`OCR_MAX_INFLIGHT` defaults to 2, accepts 1–8 and rejects invalid supplied values
at startup. Mobile owns a 45s deadline from before file setup through upload, full
body and parsing, requesting native abort/close on timeout or disposal. Upload input
cleanup is explicitly joined before settlement, even if native send finished earlier.
The mobile attempt-owned relay retains valid handles through SDK TLS handoff and
joins setup/pumps/teardown; accepted loopback endpoints are paired with the initiated
socket, with an eight-endpoint budget. SDK DNS/staggered setup and physical-platform
deadline/trust behavior remain unqualified. The client refuses
redirects/retries, caps every decoded response at 1 MiB and preflights the same flat
receipt shape/field/quantity bounds before review or bill mutation. Finite client
messages never display arbitrary server text. Manual retry remains explicit; valid
Retry-After hints are bounded to 1–86400 seconds, with longer hints omitted rather
than shortened. See [mobile verification](mobile-ocr-verification.md). Durable allowance
B and independent backend acceptance remain deferred.

---

## Error Format

All errors follow this format:

```json
{ "error": "description of what went wrong" }
```

Common HTTP status codes:
| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad request / validation error / business rule violation |
| 403 | Invalid or missing access token |
| 404 | Resource not found |
| 429 | Receipt scanning rate limit exceeded |
| 500 | Internal server error |
