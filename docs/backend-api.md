# Backend API Reference

Base URL: `http://localhost:8080` (development)

Bill reads accept the bill's `t` token, or the containing tab's token for a read-only bill view. Bill writes require the bill token. Tab writes may also require an `X-Member-Token` header; member attribution uses the optional `m` query parameter.

## Health

### `GET /health`

Returns service status.

**Response** `200`
```json
{ "status": "bill service - ok" }
```

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
to USD and display currency to receipt currency. Display codes are normalized and
checked for three-byte length, as in the separate display provider; its available pairs
are independent of the six supported frozen receipt currencies. USD receipts can use
PEN, AUD and the other mobile display choices when that provider is available. A failed
display quote returns `503` without saving. IDs, foreign keys, tab/member/payer
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
amounts and existing currency-provider behavior remain unchanged by this contract.
Bill reads omit the source access token.

### `GET /api/exchange-rates/:currency`

Preview the latest verified daily conversion from the selected currency to USD before saving a receipt.
Supported receipt currencies in 1.4.1 are `USD`, `EUR`, `GBP`, `CAD`, `JPY`, and `MXN`.

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
| 400 | `{"error": "unsupported currency code"}` | Currency is not supported by the 1.4.1 receipt selector |
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

---

## Tabs

### `POST /api/tabs`

Create a new tab. Optionally creates the creator as a member.

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

**Response** `200` — Full tab object.

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 403 | `{"error": "token mismatch"}` | Invalid access token |
| 404 | `{"error": "tab not found"}` | Tab does not exist |

### `PATCH /api/tabs/:id?t=token`

Update tab name or description. Blocked if finalized.

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
source content or SQL. This operation does not make settlement finalization atomic;
that separate consistency repair remains tracked.

---

## Finalization & Settlements

### `POST /api/tabs/:id/finalize?t=token&m=memberToken`

Finalize a tab: validate all images are processed, compute per-person settlement amounts, lock the tab.

If the tab has members, only the creator (`role: "creator"`) can finalize.

**Response** `200` — Array of created settlements.
```json
[
  { "id": 1, "tab_id": 1, "person_name": "Alice", "amount": 90.00, "paid": false },
  { "id": 2, "tab_id": 1, "person_name": "Bob", "amount": 60.00, "paid": false }
]
```

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 400 | `{"error": "tab is already finalized"}` | Already finalized |
| 400 | `{"error": "tab has no bills"}` | No bills to settle |
| 400 | `{"error": "all images must be marked as processed before finalizing"}` | Unprocessed images |
| 403 | `{"error": "only the tab creator can finalize"}` | Non-creator attempted finalize |

### `GET /api/tabs/:id/settlements?t=token`

Get all settlements for a tab.

**Response** `200`
```json
[
  { "id": 1, "tab_id": 1, "person_name": "Alice", "amount": 90.00, "paid": false, "created_at": "..." }
]
```

### `PATCH /api/tabs/:id/settlements/:settlementId?t=token`

Toggle a settlement's paid status.

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
