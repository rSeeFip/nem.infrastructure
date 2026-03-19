# Local Full Platform Runbook (wmreflect)

This runbook captures the known-good local bring-up flow for the full `nem.*` ecosystem using the unified compose file at:

- `/workspace/wmreflect/docker-compose.yml`

## 1) Prerequisites

- Docker Engine + Docker Compose plugin installed
- At least 12 GB RAM available to Docker
- Ports available on host: `3000`, `3010`, `5002-5005`, `5010-5011`, `5020`, `5050`, `5100`, `5223`, `5432`, `5672`, `8080`, `8090`, `9090`, `15672`

## 2) First-time bring-up

Run from `/workspace/wmreflect`:

```bash
docker compose build
docker compose up -d
```

## 3) Health verification

```bash
docker compose ps -a
```

Expected key healthy services:

- Core apps: `nem-mcp`, `nem-knowhub`, `nem-holisticworld`, `nem-assetcore`, `nem-mediahub`, `nem-mimir`, `nem-scheduler`, `nem-web`
- Adapters: `nem-teams-adapter`, `nem-whatsapp-adapter`, `nem-signal-adapter`
- Infra: `postgres`, `rabbitmq`, `keycloak`, `gateway`, `otel-collector`, `grafana`, `prometheus`, `loki`, `tempo`, `pgadmin`

## 4) Host URL quick reference

- MCP: `http://localhost:5002`
- KnowHub: `http://localhost:5100`
- HolisticWorld: `http://localhost:5003`
- AssetCore: `http://localhost:5004`
- MediaHub: `http://localhost:5005`
- Mimir: `http://localhost:5223`
- Scheduler: `http://localhost:5020`
- Teams adapter: `http://localhost:5010`
- WhatsApp adapter: `http://localhost:5011`
- Web: `http://localhost:3000`
- Keycloak: `http://localhost:8080`
- Gateway: `http://localhost:8090`
- Grafana: `http://localhost:3010`
- Prometheus: `http://localhost:9090`
- pgAdmin: `http://localhost:5050`
- RabbitMQ UI: `http://localhost:15672`

Port mapping can always be re-checked with:

```bash
docker compose port <service> <container-port>
```

## 5) Database notes

The stack relies on PostgreSQL databases for several services. If using a retained volume, ensure required DBs exist:

- `mcp`, `knowhub`, `mimir`, `scheduler`, `assetcore`, `holisticworld`, `keycloak`

For KnowHub vector search, ensure pgvector is available and enabled:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## 6) Known local-only behavior

- `nem-signal-adapter` can be healthy while external signal-cli API retries continue in logs if the API endpoint is not available locally.
- `nem-knowhub` health should probe `/api/v1/health/embedding` for stable readiness in this compose profile.

## 7) Troubleshooting quick commands

```bash
# Service logs
docker compose logs -f nem-knowhub

# Rebuild one service
docker compose build nem-knowhub

# Force recreate one service
docker compose up -d --force-recreate nem-knowhub

# Inspect health JSON
docker inspect --format '{{json .State.Health}}' nem-knowhub
```

## 8) Shutdown whole platform

```bash
docker compose down
```

Optional cleanup (removes named volumes too):

```bash
docker compose down -v
```
