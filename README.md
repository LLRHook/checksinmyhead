# Billington

**Privacy-first bill splitting for group trips** — [Demo](https://youtube.com/shorts/T1GHR6JgOX8?feature=share) | [Website](https://getbillington.vercel.app/)

Billington lets groups split bills, track expenses, and settle up — all without creating accounts. Share a link, add bills, and see who owes what.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Flutter App   │     │  Next.js Viewer  │
│   (iOS mobile)  │     │  (web client)    │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
          ┌──────────▼──────────┐
          │   Go API (Gin)      │
          │   port 8080         │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │   PostgreSQL 17     │
          └─────────────────────┘
```

## Quickstart

```bash
# One command — starts backend, web viewer, and iOS simulator
./dev.sh
```

Or start each service manually:

```bash
# Terminal 1: Backend
cd backend
cp .env.example .env
docker-compose up --build

# Terminal 2: Web viewer
cd web-bill-viewer
echo "NEXT_PUBLIC_API_URL=http://localhost:8080" > .env.local
npm install && npm run dev

# Terminal 3: Flutter
cd mobile
flutter run -d simulator
```

## Project Structure

```
billington/
├── backend/                  # Go API server
│   ├── cmd/bill-service/     # Main entrypoint
│   ├── internal/             # Business logic (bill, tab, receipt, currency)
│   │   ├── bill/             #   Bill CRUD (handler/service/repo)
│   │   ├── receipt/          #   Receipt OCR via Anthropic Claude API
│   │   ├── tab/              #   Tabs, members, settlements
│   ├── pkg/                  # Shared packages
│   │   ├── models/           #   GORM data models
│   │   ├── database/         #   PostgreSQL connection
│   │   └── security/         #   Token generation
│   ├── docker-compose.yml    # PostgreSQL + bill-service
│   └── Makefile
├── web-bill-viewer/          # Next.js web client
│   ├── src/app/              # App Router pages
│   │   ├── b/[id]/           #   Bill viewer (/b/:id?t=token)
│   │   └── t/[id]/           #   Tab viewer (/t/:id?t=token)
│   │   └── privacy/          #   Public privacy policy
│   ├── src/components/       # React components
│   └── src/lib/api.ts        # API client + types
├── mobile/                   # Flutter iOS app
│   └── lib/                  # Dart source
├── docs/                     # Project documentation
│   ├── technical-overview.md
│   ├── backend-api.md
│   └── privacy.md
├── dev.sh                    # Full-stack dev startup
└── README.md
```

## Core Concepts

### Tabs
A Tab is a group expense tracker (e.g. "Beach Trip 2025"). Multiple bills are added to a tab, and per-person totals are calculated across all bills. When the trip is done, the creator finalizes the tab to lock it and generate settlement amounts.

### Anonymous Member Tokens
No accounts needed. When someone creates a tab, they get an access token. Others join via a shared link and receive a member token. Tokens are stored locally and used to authorize shared-tab access and attribute bill contributions.

### Finalization & Settlements
The tab creator can finalize a trip to aggregate each person's shares across its bills and create settlements. Settlements can be toggled as paid.

## Testing

```bash
# Backend (Go)
cd backend && go test -v -race ./internal/... ./pkg/...

# Web viewer (Vitest)
cd web-bill-viewer && npm test

# Flutter
cd mobile && flutter test
```

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Mobile | Flutter / Dart | iOS app with Drift DB, Provider state |
| Web | Next.js 16 / React 19 | Server-rendered bill & tab viewer |
| API | Go / Gin | REST API with layered architecture |
| Database | PostgreSQL 17 | Primary data store via GORM |
| AI/OCR | Anthropic Claude | Receipt scanning via Messages API |
| Infra | Docker Compose | Local development environment |

## Roadmap

- [x] Foundation — Go API, PostgreSQL, Bill CRUD
- [x] Bill Sharing — Web viewer, Venmo deep links
- [x] Tabs & Group Trips — Multi-bill tabs, per-person totals
- [x] Receipt Scanning — Selected receipt images parsed through Anthropic Claude
- [x] Finalization — Settlements, paid tracking
- [x] Account-less Collaboration — Anonymous member tokens
- [x] Documentation & Testing — Tests, docs, dev script
- [x] Receipt OCR — Anthropic Claude API for receipt scanning
- [ ] Production Deployment — Cloud hosting, CDN, monitoring

## Documentation

- [Technical Overview](docs/technical-overview.md) — Architecture, data models, design decisions
- [Backend API Reference](docs/backend-api.md) — Full endpoint documentation
- [Privacy](docs/privacy.md) — What Billington stores and sends to service providers
- [Market Analysis](docs/market-analysis.md) — Competitive landscape
- [Contributing](docs/contribution.md) — Development guidelines

## License

GNU GPL — see [LICENSE](LICENSE).
