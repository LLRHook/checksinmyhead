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
select it. Both service Dockerfiles pin the same official Go builder and supported
`gcr.io/distroless/base-nossl-debian13:nonroot` runtime by multi-platform digest.
The runtime retains libc for the existing CGO build, CA certificates and timezone
data, and omits OpenSSL. Builders use
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

### Container liveness

Both images execute as UID/GID **65532:65532**. Application binaries/directories
remain root-owned and readable/executable; the legacy viewer retains its relative
`internal/web/templates` path under `/app`. Containers can use a read-only root
filesystem with a writable `/tmp` tmpfs (mode 1777, UID/GID 65532).

The default commands remain `./bill-service` (8080) and `./web-service` (8081).
Each binary also supports `--healthcheck`, dispatched before database setup.
It makes one GET to its fixed `127.0.0.1` `/health` address, requires HTTP 200
and the service's expected JSON status, limits the whole request to two seconds
and the body to 4096 bytes, rejects redirects, bypasses proxies, and exits 0/1
without printing responses or transport errors.

Docker's exec-form `HEALTHCHECK` calls that same binary every 30 seconds with a
three-second outer timeout, a ten-second start period and three retries. No
helper runtime packages are required. This is HTTP liveness after startup;
`/health` does not query the database on each request. Hosting health/readiness
configuration and operator-injected commit values require separate verification.
See the [runtime validation evidence](../docs/reviews/2026-11-02-runtime-lock-images.md)
for image identities, signature checks and retained vulnerability findings.

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
