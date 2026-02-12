# Backend API Reference

Base URL: `http://localhost:8080` (development)

All tab and bill endpoints require an access token passed as the `t` query parameter. Member attribution uses the optional `m` query parameter.

## Health

### `GET /health`

Returns service status.

**Response** `200`
```json
{ "status": "bill service - ok" }
```

---

## Bills

### `POST /api/bills`

Create a new bill.

**Request Body**
```json
{
  "name": "Dinner at Chilis",
  "subtotal": 138.00,
  "tax": 8.28,
  "tip_amount": 27.60,
  "tip_percentage": 20.0,
  "total": 173.88,
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

**Response** `201`
```json
{
  "bill_id": 1,
  "access_token": "abc123...",
  "share_url": "https://billington.app/b/1?t=abc123..."
}
```

### `GET /api/bills/:id?t=token`

Get a bill by ID.

**Response** `200` — Full bill object with items, participants, person_shares, payment_methods.

**Errors**
| Status | Body | Meaning |
|--------|------|---------|
| 403 | `{"error": "token mismatch"}` | Invalid access token |
| 404 | `{"error": "bill not found"}` | Bill does not exist |

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

## Images

### `POST /api/tabs/:id/images?t=token&m=memberToken`

Upload a receipt image. Multipart form data with `image` field.

- Max file size: 10MB
- Accepted MIME types: `image/jpeg`, `image/png`, `image/gif`, `image/webp`
- Rate limit: 20 uploads per hour per tab
- Blocked if tab is finalized

**Response** `201`
```json
{
  "id": 1,
  "tab_id": 1,
  "filename": "abc123.jpg",
  "url": "/uploads/abc123.jpg",
  "size": 245760,
  "mime_type": "image/jpeg",
  "processed": false,
  "uploaded_by": "Alice"
}
```

### `GET /api/tabs/:id/images?t=token`

List all images for a tab.

**Response** `200` — Array of TabImage objects.

### `PATCH /api/tabs/:id/images/:imageId?t=token`

Update image metadata (e.g. mark as processed).

**Request Body**
```json
{ "processed": true }
```

**Response** `200`
```json
{ "status": "ok" }
```

### `DELETE /api/tabs/:id/images/:imageId?t=token`

Delete an image. Blocked if tab is finalized.

**Response** `200`
```json
{ "status": "ok" }
```

---

## Static Files

### `GET /uploads/:filename`

Serves uploaded images from the upload directory.

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
| 429 | Rate limit exceeded (image uploads) |
| 500 | Internal server error |
