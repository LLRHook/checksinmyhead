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
└── image/                    # Image upload & management
    ├── handler.go            #   Multipart upload, MIME validation
    ├── service.go            #   Image business logic
    ├── repository.go         #   Image CRUD
    └── ratelimit.go          #   20 uploads/hour per tab
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

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `postgres` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `billington_data` | Database name |
| `DB_USER` | `billington_admin` | Database user |
| `DB_PASSWORD` | `changeme` | Database password |
| `UPLOAD_DIR` | `./uploads` | Image upload directory |

## Testing

```bash
go test -v -race ./internal/... ./pkg/...
```

Tests use manual mocks of repository interfaces — no database required.

## API Documentation

See [docs/backend-api.md](../docs/backend-api.md) for the full endpoint reference.
