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

Create a new bill.

**Request Body**
```json
{
  "name": "Dinner at Chilis",
  "lazy_mode": false,
  "subtotal": 138.00,
  "tax": 8.28,
  "tip_amount": 27.60,
  "tip_percentage": 20.0,
  "total": 173.88,
  "currency_code": "EUR",
  "participants": [
    { "name": "Alice" },
    { "name": "Bob" }
  ],
  "items": [
    {
      "name": "Pizza",
      "price": 20.00,
      "assignments": [
        { "person_name": "Alice", "percentage": 50 },
        { "person_name": "Bob", "percentage": 50 }
      ]
    }
  ],
  "person_shares": [
    {
      "person_name": "Alice",
      "items": [{ "name": "Pizza", "amount": 10.00, "is_shared": true }],
      "subtotal": 10.00,
      "tax_share": 0.60,
      "tip_share": 2.00,
      "total": 12.60
    }
  ],
  "payment_methods": [
    { "name": "Venmo", "identifier": "@alice" },
    { "name": "Zelle", "identifier": "555-1234" }
  ]
}
```

Set `lazy_mode` to `true` for an item-claim bill. The bill remains standalone and is shared at `/b/:id`; creating it does not create a tab. Participants and person shares may be empty while people claim receipt items.

**Response** `201`
```json
{
  "bill_id": 1,
  "access_token": "abc123...",
  "share_url": "https://billington.app/b/1?t=abc123...",
  "currency_code": "EUR",
  "usd_exchange_rate": 1.1652,
  "exchange_rate_date": "2026-08-29",
  "exchange_rate_source": "frankfurter-v2-blended",
  "usd_total": 202.59
}
```

`currency_code` defaults to `USD` for older clients. For non-USD bills the service fetches the latest available daily rate, validates it, and freezes the returned rate/date/source on the created bill. A failed or invalid provider response returns `503`; the bill is not saved. Clients must not calculate or submit their own authoritative rate.

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

Assignments must use unique, non-empty names of at most 30 characters and total 100 percent. An empty array releases an unpaid item's claim. Items in a paid share are locked. This endpoint rejects ordinary bills and bills already attached to a trip.

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

Add an existing bill to a tab. The `m` parameter is optional and attributes the bill to a member.

**Request Body**
```json
{ "bill_id": 5 }
```

**Response** `200`
```json
{ "status": "ok" }
```

**Errors**
- `400` if tab is finalized.

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
