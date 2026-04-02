# nem.infrastructure — Agent Notes

> Composable Docker Compose stacks. PostgreSQL, RabbitMQ, Keycloak, OPA, OpenBao, Tempo, Grafana, YARP Gateway.

## Overview

Centralized infrastructure definitions for the nem.* ecosystem. Contains Docker Compose files for shared services that multiple nem.* repos depend on. Run once, share across all services during local development.

## Compose Files

| File | Services | Purpose |
|------|----------|---------|
| `docker-compose.yml` | postgres, rabbitmq, keycloak, opa, vault, pgadmin, gateway, otel-collector, prometheus, loki, tempo, grafana, postgres-exporter, cadvisor | Full stack (core + observability) |
| `docker-compose.rabbitmq.yml` | nem-rabbitmq | Standalone RabbitMQ (alt transport) |
| `docker-compose.classification.yml` | postgres, rabbitmq, keycloak, opa, vault, prometheus, loki | Classification/Comms focused stack |

## Services & Ports

| Service | Port | Image | Notes |
|---------|------|-------|-------|
| PostgreSQL | 5432 | postgres:17 | Primary datastore, pgvector support |
| RabbitMQ | 5672 / 15672 | rabbitmq:3-management | AMQP broker + UI |
| Keycloak | 8080 | quay.io/keycloak/keycloak:26.0 | OIDC/JWT, start-dev mode |
| OPA | 8181 | openpolicyagent/opa:latest | Policy engine, server mode |
| OpenBao | 8200 | openbao/openbao:latest | Secrets, dev mode |
| pgAdmin | 5050 | dpage/pgadmin4:latest | PostgreSQL UI |
| Gateway | 8090 | nem.Gateway (local build) | YARP reverse proxy |
| OTEL Collector | 4317 / 4318 | otel/opentelemetry-collector-contrib:0.115.0 | gRPC/HTTP OTLP ingest |
| Prometheus | 9090 | prom/prometheus:v2.54.1 | Metrics time-series DB |
| Loki | 3100 | grafana/loki:3.3.2 | Logs aggregation |
| Tempo | 3200 | grafana/tempo:2.6.1 | Traces (replaces Jaeger) |
| Grafana | 3010 | grafana/grafana-oss:11.4.0 | Dashboards, multi-source querying |
| Postgres Exporter | 9187 | prometheuscommunity/postgres-exporter:v0.16.0 | DB metrics → Prometheus |
| cAdvisor | 8085 | gcr.io/cadvisor/cadvisor:v0.49.1 | Container metrics |

## Patterns

- **Composable**: Use `-f` flag to combine services. Full stack via single file; pick-and-mix with rabbitmq/classification variants.
- **Healthchecks**: All services include health probes (postgres, rabbitmq, keycloak, otel, prometheus, loki, tempo, grafana).
- **Networks**: All services on `nem-network` bridge (created externally).
- **Secrets**: Use `.env.classification` for environment profiles; OpenBao for runtime secrets.
- **Observability Stack**: Prometheus (metrics) → Loki (logs) → Tempo (traces) → Grafana (unified dashboard).

## Usage

```bash
# Full stack (all services)
docker compose up -d

# Core only (no observability)
docker compose -f docker-compose.yml --profile="" up -d

# With standalone RabbitMQ
docker compose -f docker-compose.yml -f docker-compose.rabbitmq.yml up -d

# Classification profile
docker compose -f docker-compose.classification.yml --profile=full-stack up -d
```

## Database Setup

Run `init-databases.sh` to create per-service databases in shared PostgreSQL:
- nem_mcp, nem_knowhub, nem_classification, nem_comms, etc.

Never commit `.env` or secrets files; use OpenBao for credentials in production.
