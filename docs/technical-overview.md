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

**Service** — Defines interfaces for testability. Contains all business logic: finalization validation, settlement calculation, member token generation.

**Repository** — Wraps GORM queries. Uses `Preload` for eager loading of nested associations (e.g. `Bills.Items.Assignments`).

## Frontend Architecture

### Flutter (Mobile)

- **State Management**: Provider pattern for unidirectional data flow
- **Local Database**: Drift ORM (SQLite) for offline bill storage and tab metadata
- **API Client**: HTTP service for backend communication with fire-and-forget sync
- **Schema Migrations**: Drift schema v8

### Next.js (Web Viewer)

- **Rendering**: App Router with React Server Components for initial data fetch
- **Pages**: `/b/[id]` for bill viewing, `/t/[id]` for tab viewing
- **Client Components**: LazyBillBoard, MemberList, SettlementCard, and bill/tab breakdowns
- **API Client**: `src/lib/api.ts` with typed fetch functions and `computeTabPersonTotals` aggregation

## Key Technical Decisions

### Anonymous Tokens Instead of Accounts
Users never create accounts. Access is controlled by 64-character cryptographic tokens generated with Go's `crypto/rand.Text()`. Tab creators and members each receive unique tokens that are stored locally on their devices.

### JSONB for Flexible Data
`PaymentMethods` and `PersonShare.Items` use PostgreSQL JSONB columns via GORM's `serializer:json` tag. This avoids extra join tables for data that is always read and written as a unit.

### Monolith Over Microservices
A single `bill-service` binary handles all endpoints. The layered architecture (handler/service/repository) provides separation of concerns without the operational overhead of multiple services.

### Anthropic Claude for Receipt OCR
Receipt scanning sends a selected image from the mobile app to the backend. The backend sends the image to Anthropic's Claude Messages API with an extraction prompt and returns parsed receipt fields. The receipt parsing endpoint does not persist the uploaded image.

### Local-First Mobile
The Flutter app maintains its own Drift database for offline access and fast reads. Backend sync is fire-and-forget — the app works without network access for local bills.

## Security Model

- **Token-based access**: Every tab and bill has a unique access token. Protected reads accept a bearer token or the legacy `?t=` link parameter.
- **No accounts**: Billington does not ask users to create accounts, but shared bills and tabs contain user-provided names and payment handles and are stored online.
- **Member attribution**: Write operations optionally accept `?m=memberToken` for attribution without authentication.
- **CORS**: Restricted to configured browser origins; CORS is not an authorization control.
- **Receipt scan limits**: Receipt parsing is limited to 10 requests per minute per client IP and images are limited to 10MB.

## Testing Strategy

### Backend (Go)
Unit tests for the service layer use manual repository mocks and cover finalization validation, settlement calculation, member creation, and error paths.

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
