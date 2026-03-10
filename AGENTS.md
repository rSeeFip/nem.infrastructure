# infrastructure — Agent Notes

> Shared Docker Compose infrastructure. PostgreSQL, RabbitMQ, Keycloak, OPA, OpenBao, Jaeger, YARP gateway.

## Overview

Centralized infrastructure definitions for the nem.* ecosystem. Contains Docker Compose files for shared services that multiple nem.* repos depend on. Run once, share across all services during local development.

## Structure

```
infrastructure/
├── docker-compose.yml              # Core: PostgreSQL, Keycloak, OPA, OpenBao
├── docker-compose.rabbitmq.yml     # RabbitMQ broker
├── docker-compose.jaeger.yml       # Jaeger distributed tracing
├── init-databases.sh               # Database initialization script
├── yarp-gateway.json               # YARP reverse proxy/API gateway config
```

## Key Patterns

- **Composable Stacks**: Multiple compose files for opt-in services. Use `-f` to combine.
- **Shared Databases**: `init-databases.sh` creates per-service databases in shared PostgreSQL.
- **YARP Gateway**: Reverse proxy routing for unified API access during dev.
- **Infrastructure-as-Code**: All infra defined declaratively. No manual setup.

## Usage

```bash
# Full stack
docker compose -f docker-compose.yml -f docker-compose.rabbitmq.yml -f docker-compose.jaeger.yml up -d

# Core only (PostgreSQL, Keycloak, OPA, OpenBao)
docker compose up -d

# With RabbitMQ
docker compose -f docker-compose.yml -f docker-compose.rabbitmq.yml up -d
```

## Port Map

| Service | Port |
|---------|------|
| PostgreSQL | 5432 |
| RabbitMQ | 5672 (AMQP) / 15672 (UI) |
| Keycloak | 8080 |
| OPA | 8181 |
| OpenBao | 8200 |
| Jaeger | 16686 (UI) / 4317 (OTLP) |

## Conventions

- Each nem.* service's `docker-compose.yml` references these shared services.
- Database names: per-service (e.g., `nem_mcp`, `nem_knowhub`). Created by `init-databases.sh`.
- Never commit secrets — use OpenBao for all credentials.
