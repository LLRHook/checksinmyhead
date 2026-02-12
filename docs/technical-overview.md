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

Created when a tab is finalized. Tracks who owes what.

```go
type TabSettlement struct {
    ID         uint
    TabID      uint
    PersonName string
    Amount     float64
    Paid       bool      // Toggle via PATCH
}
```

### TabImage

Receipt photos attached to a tab. Must be marked as processed before finalization.

```go
type TabImage struct {
    ID         uint
    TabID      uint
    Filename   string
    URL        string
    Size       int64
    MimeType   string
    Processed  bool      // Must be true to finalize
    UploadedBy string    // Member attribution
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
├── tab/
│   ├── handler.go      # Tab CRUD, join, finalize, settlements
│   ├── service.go      # Finalization logic, member management
│   └── repository.go   # Tab queries with eager loading
└── image/
    ├── handler.go       # Multipart upload, MIME validation
    ├── service.go       # Image business logic
    ├── repository.go    # Image CRUD
    └── ratelimit.go     # 20 uploads/hour per tab
```

**Handler** — Parses HTTP requests, validates access tokens, calls service methods, returns JSON responses. No business logic lives here.

**Service** — Defines interfaces for testability. Contains all business logic: finalization validation, settlement calculation, member token generation.

**Repository** — Wraps GORM queries. Uses `Preload` for eager loading of nested associations (e.g. `Bills.Items.Assignments`).

## Frontend Architecture

### Flutter (Mobile)

- **State Management**: Provider pattern for unidirectional data flow
- **Local Database**: Drift ORM (SQLite) for offline bill storage and tab metadata
- **API Client**: HTTP service for backend communication with fire-and-forget sync
- **Schema Migrations**: Drift schema v5 with member token and role columns

### Next.js (Web Viewer)

- **Rendering**: App Router with React Server Components for initial data fetch
- **Pages**: `/b/[id]` for bill viewing, `/t/[id]` for tab viewing
- **Client Components**: JoinTabButton (with localStorage persistence), MemberList, SettlementCard, TabImageGallery with lightbox
- **API Client**: `src/lib/api.ts` with typed fetch functions and `computeTabPersonTotals` aggregation

## Key Technical Decisions

### Anonymous Tokens Instead of Accounts
Users never create accounts. Access is controlled by 64-character cryptographic tokens generated with Go's `crypto/rand.Text()`. Tab creators and members each receive unique tokens that are stored locally on their devices.

### JSONB for Flexible Data
`PaymentMethods` and `PersonShare.Items` use PostgreSQL JSONB columns via GORM's `serializer:json` tag. This avoids extra join tables for data that is always read and written as a unit.

### Monolith Over Microservices
A single `bill-service` binary handles all endpoints. The layered architecture (handler/service/repository) provides separation of concerns without the operational overhead of multiple services.

### Local-First Mobile
The Flutter app maintains its own Drift database for offline access and fast reads. Backend sync is fire-and-forget — the app works without network access for local bills.

## Security Model

- **Token-based access**: Every tab and bill has a unique access token. No request succeeds without a valid `?t=` parameter.
- **No PII stored**: Display names are user-chosen and not verified. No emails, passwords, or phone numbers.
- **Member attribution**: Write operations optionally accept `?m=memberToken` for attribution without authentication.
- **CORS**: Open to all origins (designed for public link sharing).
- **Rate limiting**: Image uploads limited to 20 per hour per tab.
- **File validation**: Uploads restricted to image MIME types, max 10MB.

## Testing Strategy

### Backend (Go)
Unit tests for the service layer using manual mocks of repository and image querier interfaces. Tests cover business logic: finalization validation, settlement calculation, member creation, error paths.

```bash
cd backend && go test -v -race ./internal/... ./pkg/...
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
