# Billington Backend

Go API server for Billington, built with Gin and PostgreSQL via GORM.

## Architecture

```
cmd/bill-service/main.go     # Entrypoint, route registration, middleware
internal/
├── bill/                     # Bill CRUD
│   ├── handler.go            #   HTTP handlers
│   ├── service.go            #   Business logic
│   └── repository.go         #   Database queries
├── tab/                      # Tabs, members, settlements
│   ├── handler.go            #   Join, finalize, settlement endpoints
│   ├── service.go            #   Finalization logic, member management
│   └── repository.go         #   Tab queries with eager loading
pkg/
├── models/                   # GORM data models (Tab, Bill, TabMember, etc.)
├── database/postgres.go      # DB connection + AutoMigrate
└── security/token.go         # Cryptographic token generation
```

Each module follows the **Handler → Service → Repository** pattern. Services define interfaces for testability. Repositories use GORM with eager loading via `Preload`.

## Quick Start

```bash
# 1. Set up environment
cp .env.example .env

# 2. Start PostgreSQL + API server
docker-compose up --build

# 3. Verify
curl localhost:8080/health
```

## Development Commands

```bash
make up       # Start services (docker-compose up --build)
make down     # Stop services and remove volumes
make logs     # Tail service logs
make test     # Run Go unit tests (go test -v -race ./internal/... ./pkg/...)
```

Or use the root `./dev.sh` script to start the full stack (backend + web + mobile).

### Build toolchain

`go.mod` requires Go 1.27.3. Local commands may use `GOTOOLCHAIN=auto` to
select it. Both service Dockerfiles pin the same official Go builder and the
existing Debian 12 distroless runtime by multi-platform digest. Builders use
`GOTOOLCHAIN=local` so a mismatched module requirement fails instead of downloading
another compiler. Update the module and both builder pins together after checking
current security releases and image identities.

Build from the `backend` context, for example from the repository root:

```bash
docker build --pull --no-cache --platform linux/amd64 -f backend/services/bill-service/Dockerfile -t billington-bill:validation backend
docker build --pull --no-cache --platform linux/amd64 -f backend/services/web-service/Dockerfile -t billington-web:validation backend
```

`.dockerignore` excludes local environment files, private-key files, generated
binaries/data and verification output; it retains source, test fixtures and
`.env.example`. Pass runtime credentials through the environment, never by copying
them into the image. These local builds do not establish the hosting platform's
architecture or deployment identity; see [verification](../VERIFICATION.md).

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `postgres` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `billington_data` | Database name |
| `DB_USER` | `billington_admin` | Database user |
| `DB_PASSWORD` | `changeme` | Database password |
| `EXCHANGE_RATE_API_KEY` | — | Server-only ExchangeRate-API key used for cross-currency conversion |
| `MINIMUM_SUPPORTED_APP_VERSION` | `2.0.3` | Lowest mobile version allowed to continue after the startup policy check (numeric `major.minor.patch`) |
| `APP_STORE_URL` | Billington App Store page | Store destination returned with the public version policy |

Cross-currency bills require `EXCHANGE_RATE_API_KEY`. Same-currency bills continue to work without it; never put this key in the mobile app or web bundle.

The public `GET /api/app/version-policy` endpoint is consumed at app startup. Raise `MINIMUM_SUPPORTED_APP_VERSION` only after the corresponding update is available in the store, and use a three-part numeric version such as `2.1.0`. The app fails open if the endpoint times out or returns invalid data; the version check is a user-facing compatibility gate, not an authorization control. Version policy responses are sent with `Cache-Control: no-store`.

Request logs intentionally omit query strings because share and member bearer tokens may appear in them. Do not change the request logger to include `RequestURI`, `RawQuery`, or Gin's default `Path` field.

## Testing

```bash
go test -v -race ./internal/... ./pkg/...
```

Tests use manual mocks of repository interfaces — no database required.

## API Documentation

See [docs/backend-api.md](../docs/backend-api.md) for the full endpoint reference.
