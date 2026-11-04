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

The retained legacy web service uses the same readiness check and fields, with healthy
status `web service - ok`. The `--healthcheck` loopback command treats HTTP 503 as failure.
See [schema startup modes](../backend/README.md#postgresql-schema-startup) for migration-only
and verify startup behavior. No receipt/quote/payment payload changes are introduced.

### `GET /api/app/version-policy`

Returns the public mobile compatibility policy. Response headers include `Cache-Control: no-store` so operators can raise the minimum without stale client caches. The mobile client fails open if the endpoint is unavailable; this is not an API authorization mechanism.

```json
{
  "minimum_supported_version": "2.0.3",
  "store_url": "https://apps.apple.com/app/id6746379502"
}
```

Set `MINIMUM_SUPPORTED_APP_VERSION` on the bill service to a numeric `major.minor.patch` value only after the new release is available in the store. Invalid values fall back to `2.0.3`.

---

## Bills

### `POST /api/bills`

Create a new **standalone** bill from content. Attach it to a tab separately using
the returned source-bill token.

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
existing most-recent-claim, then alphabetical-name order. Zero-share participants and
repeated item descriptions are preserved.
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
write those frozen date/source fields. Separate persisted display observation/source/
retrieval metadata requires approved migration 0002; no schema change is made here.
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
freeze or change any saved receipt. The mobile decoder still reading `value` is an
explicit next-phase client correction.

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

### `PATCH /api/bills/:id/items/:itemId/assignments`

Update one item's claim on a standalone lazy bill. Supply the bill access token as `Authorization: Bearer <token>` or `?t=<token>`. The item timestamp is an optimistic concurrency precondition; stale writes return `409` and should refresh the bill.

**Request Body**
```json
{
  "expected_updated_at": "2026-10-10T17:30:54.055105Z",
  "assignments": [
    { "person_name": "Alex", "percentage": 100 }
  ]
}
```

Assignments must use unique, non-empty names of at most 30 characters and total no more than 100 percent; any unassigned percentage remains available to claim. An empty array releases an unpaid item's claim. Paid assignments cannot be removed or changed, while the unclaimed remainder may still be claimed. This endpoint rejects ordinary bills and bills already attached to a trip.

**Response** `200`: `{"status":"ok"}`

**Errors** `400` for invalid assignments/non-lazy bills, `403` for an invalid token, `404` for a missing bill item, and `409` for stale or paid-item conflicts.

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
before bill and is allowed after finalization. Tab-share payment also checks current
membership and the existing Unicode `EqualFold` name rule under lock. Ambiguity uses
that same relation for member and share candidates, independent of SQL collation.
Multiple matching shares return `409 accounting_review_required` before any paid
update, including equal-flag retries. This contains observable collisions; stable
identity remains separate work.
Both payment routes change only the selected receipt paid flag, with scoped `404` for
stale IDs. Generic `503`/`500` responses never expose database messages.

All attached writers use Tab → Bills by ID → Items by ID → Shares; settlement writes
use Tab → Settlement. Membership/settings take Tab first. Mutations use the request
context with a 10-second maximum (earlier caller deadlines win). This protocol requires
all deployed writers to cooperate. It does not establish rollout or signed-client proof.

---

## HTTP resource policy

Both service binaries use read-header/read/write/idle timeouts of 5/20/50/60 seconds
and a 32 KiB `MaxHeaderBytes` setting. Signal cancellation reaches request contexts;
shutdown waits at most 25 seconds, then closes connections. A write deadline alone
does not cancel handler work. Recovery returns a generic JSON 500 before response
commitment, and aborts partial/disconnected responses without appending a false 500.
Process diagnostics never print raw panic values, requests, headers, bodies or stacks.

All JSON mutation routes share eight in-flight slots per process, independently of
`Content-Type`. There is no waiting queue: saturation returns 503 with `Retry-After: 1`.
Reads and health bypass the gate. CORS exposes `Retry-After` to permitted origins.
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
using Gin's right-to-left trusted-hop policy with socket fallback; mapped IPv4 client
addresses are normalized. `X-Real-IP` and platform/AppEngine headers are ignored.
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

Get a tab with all bills, items, assignments, person shares, and members.

**Response** `200` — Full tab object. `total_amount` sums validated frozen USD cents,
including genuine zero values, independently of each bill's display currency.

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 403 | `{"error": "token mismatch"}` | Invalid access token |
| 404 | `{"error": "tab not found"}` | Tab does not exist |
| 409 | `{"error":"accounting review required","code":"accounting_review_required"}` | Authorized tab contains unavailable or inconsistent frozen USD evidence, or an unsafe aggregate |

Access is checked before returning the accounting-review response. Stored receipts
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
destination-tab then source-bill row locks. Active same-tab retries revalidate all
credentials and succeed without changing attribution, timestamps or quote metadata.
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
| 200 | Authorized first attachment or active-tab retry |

The existing token API uses `403` for failed capabilities. Errors never echo tokens,
source content or SQL. Attachment participates in the tab-root protocol shared with
finalization and all competing attached writes.

---

## Finalization & Settlements

### `POST /api/tabs/:id/finalize?t=token&m=memberToken`

Finalize once in one authorized Read Committed transaction: lock the tab, resolve
current creator or genuinely memberless authority, read persisted accounting/shares,
insert gross USD settlements and mark finalized. A supplied invalid member token
fails even on a memberless tab. No quote lookup, item graph or revaluation occurs.

An authorized repeat returns the stored snapshot, ordered by `amount DESC, id ASC`,
with the same IDs, amounts, creation/finalization times and current settlement paid
flags. A lost successful response can be retried. The operation returns success only
after commit. Gross allocations, receipt-share paid flags, settlement paid flags and
net payer balances are distinct; neither flag proves an external transfer.

Foreign accounting needs valid frozen rate/date/source/total evidence. Legitimate
frozen USD zero and known legacy USD identity are supported without backfill.
No bills or no allocated share rows leaves the tab active; explicit zero participant
rows count as allocations. Detectable duplicate member labels or normalized share
keys within one bill require review, without guessing participant ownership.

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
| 409 | `accounting_review_required`: active orphan settlements, missing/ambiguous finalized results, duplicate labels/shares, invalid frozen evidence or unsafe money |
| 503 | Generic temporary unavailability; retry |
| 500 | Generic unexpected failure; no database text |

Review errors preserve stored history. Authorized reads remain available. Production
adoption and exclusion of old writers still need separate deployment evidence.

### `GET /api/tabs/:id/settlements?t=token`

Get all settlements for a tab.

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
bill payer/adder (`409 member_referenced`), including historical cross-tab references.
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

Parse a receipt image using Anthropic's Claude Messages API. No user authentication is required. The image is processed for the request and is not saved in Billington's database. Requests are limited to 10 per minute per client IP.

**Request**: Multipart form data with `image` field.

- Max file size: 10MB
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
| 400 | `{"error": "image field is required"}` | Missing `image` in form data |
| 400 | `{"error": "unsupported image type: ..."}` | Invalid MIME type |
| 429 | `{"error": "Too many scans. Please wait a moment and try again.", "code": "rate_limited"}` | Too many requests from this IP |
| 503 | Scanner unavailable response | Anthropic credentials, capacity, or service unavailable |
| 422 | Receipt parsing error response | Image could not be parsed |

**Environment**: Requires the backend-only `ANTHROPIC_API_KEY`. When it is missing, the receipt parsing route is not registered.

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
