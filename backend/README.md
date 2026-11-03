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
├── database/postgres.go      # DB connection + checked schema startup
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
make test     # Run default Go suite (go test -v -race ./...)
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
helper runtime packages are required. `/health` checks the live database and required
ledger prefix on each request, with a one-second deadline. Hosting health/readiness
configuration and operator-injected commit values require separate verification.
See the [runtime validation evidence](../docs/reviews/2026-11-02-runtime-lock-images.md)
for image identities, signature checks and retained vulnerability findings.

## PostgreSQL schema startup

Both maintained binaries apply/verify `migrations/0001_baseline.sql` before serving;
production startup no longer uses GORM AutoMigrate. The SQL and its catalog recognizer
have independent immutable SHA-256 pins and provenance. Version 0002 is reserved for
separately approved receipt replay/display metadata; it is not implemented here.

```bash
# Existing command: apply pending migrations, then serve
./bill-service
# Same binary, apply and exit without routes/provider initialization
./bill-service --migrate-only
# Verify the required schema/history without applying, then serve
./bill-service --schema-mode=verify
```

`web-service` supports the same options. `--schema-mode` accepts only `apply` (default)
or `verify`; invalid flags/values/combinations fail with a generic error. Verify mode
requires an initialized ledger. `--migrate-only` requires apply mode. There is no
migration environment alias or separate binary. `--healthcheck` remains a separate,
silent loopback probe and cannot be combined with startup options.

One Read Committed transaction takes an application/target-schema advisory lock **before
reading or creating the ledger**. Lock acquisition is limited to five seconds, total
startup schema work to sixty seconds. All pending DDL/DML, catalog validation and ledger
inserts commit together; every error, including commit, prevents serving. A competing
starter rereads history after acquiring the lock. No automatic retries hide failures.

Fresh targets receive the frozen released `81a564f`/`f1d62374` footprint. Unledgered
legacy targets must match its actual tables, columns/types/nullability/defaults,
sequences, keys, FKs and index definitions. Partial/unknown definitions fail closed;
unrelated extension tables/objects are ignored. The structured PostgreSQL 17 catalog
manifest avoids dependence on pg_dump formatting and physical column order. Do not
regenerate the baseline or recognizer from current models; append a reviewed migration
or separately versioned recognizer. `schema_migrations` records contiguous version,
name, SQL checksum, independent validation checksum, epoch and database timestamp.
Known history is immutable; same-epoch additive later versions may extend the known
prefix and are retained by older schema-aware binaries. Unknown epochs or a changed
known prefix fail startup/readiness. This does not authorize arbitrary later DDL.

The historical unconditional payer backfill is **retired**. Startup never fills or
recalculates historical rows: IDs, tokens, JSONB, quote/display provenance, payment
flags, null, dangling and cross-tab payer references remain as recorded. Those payer
anomalies need explicit review/containment in later financial operations; successful
schema startup does not make them financially valid.

Readiness performs one live ledger query within one second, retaining healthy `status`
and `commit` fields and returning generic HTTP 503 otherwise. Catalogs are checked at
startup, not on every health call; rerun verify after out-of-band schema changes.
There are no accounting scans, provider calls or readiness cache.

Before production adoption, separately verify the actual schema, backups and isolated
restore, hosting command/privileges and rollout bridge/drain of older uncooperative
writers. No production migration or predeploy configuration has been performed here.
Keep additive schema/ledger history on application rollback; never run a replay-ignorant
server once keyed clients are active. Database restore is a separate verified procedure.

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

SQL logs omit query text, bind values and driver messages at every log level, including startup failures. They retain only elapsed time, row counts, allowlisted operation/table/error categories and known SQLSTATE codes; unknown values become `unknown`. `DB_SLOW_QUERY_MS` sets the slow threshold (default 500 ms); invalid or overflowing values use that default with a fixed warning that omits the supplied value. The missing-database-env guard remains static. These controls do not redact unrelated provider or application logs.

## Testing

```bash
go test -race ./...
# Explicit loopback billington_test fixture, owned random schemas; see VERIFICATION.md:
go test -race -tags=integration ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres
```

The default suite combines mocks and SQLite fixtures. The explicit PostgreSQL layer
uses one strict shared harness and the real runner for current schemas, with a separate
frozen SQL fixture for legacy adoption. Missing/unsafe DSNs fail instead of skipping.
It covers migration history/definitions, observed lock waits, rollback/commit failure,
interruption/retry, binary startup modes and bounded live health, alongside existing
authorization/money tests. Synthetic test-only pending versions are never embedded in
the production registry. No whole-product V&V pass is implied.

## API Documentation

See [docs/backend-api.md](../docs/backend-api.md) for the full endpoint reference.
