# Go Backend

A microservices-based backend for bill splitting, built with Go and PostgreSQL.

## Quick Start

1. Copy environment template:
```bash
cp .env.example .env
```

2. Start services:
```bash
docker-compose up --build
```

3. Test the service:
```bash
curl localhost:8080/health
```

## Services

- **bill-service**: Main API service (port 8080)
- **postgres**: Database (internal only)

## Architecture Decisions

- **Go**: Performance, concurrency, cloud-native ecosystem
- **PostgreSQL**: ACID compliance and reliability
- **Microservices**: Scalability and maintainability
- **Docker**: Consistent development environment