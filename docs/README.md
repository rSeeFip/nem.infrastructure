# nem.infrastructure

## Repository Purpose
`nem.infrastructure` contains shared infrastructure configuration for running the nem.* ecosystem locally or in development-like environments. It centralizes Docker Compose definitions, reverse-proxy routing, observability provisioning, and supporting bootstrap/smoke-test scripts.

## Setup
1. Install Docker Engine + Docker Compose plugin.
2. Create required docker network when needed:

```bash
docker network create nem-network
```

3. For classification/comms-focused stack, prepare `.env.classification`.
4. Ensure sibling service repositories exist when compose files build images from relative paths.

## Usage
- Full shared stack:

```bash
docker compose -f docker-compose.yml up -d
```

- Classification/comms profile stack:

```bash
docker compose --env-file .env.classification -f docker-compose.classification.yml --profile full-stack up -d
```

- RabbitMQ-only transport:

```bash
docker compose -f docker-compose.rabbitmq.yml up -d
```

## Verification
- Gateway health endpoint:

```bash
curl -f http://localhost:8090/health
```

- Full stack smoke test (classification profile):

```bash
bash scripts/test-full-stack.sh
```

- Validate compose syntax before startup:

```bash
docker compose -f docker-compose.yml config >/dev/null
```

## Contribution Rules
- Keep infrastructure docs and compose/runtime files aligned; avoid undocumented route or port changes.
- Preserve health checks when modifying services; they are used by automated smoke validation.
- Restrict docs-only commits to `docs/` paths when the task is documentation-only.
- Avoid committing secret-bearing environment files.

## Directory Map
- `docker-compose.yml`: core + observability platform stack.
- `docker-compose.classification.yml`: classification/comms and related dependencies via profiles.
- `docker-compose.rabbitmq.yml`: standalone broker deployment.
- `nem.Gateway/Program.cs`: YARP host bootstrap and env override wiring.
- `yarp-gateway.json`: route/cluster topology for API and frontend hostnames.
- `prometheus/prometheus.yml`: scrape topology and target labeling.
- `scripts/test-full-stack.sh`: automated readiness checks.

## Cross-References and Glossary Usage
- Topology and deployment reasoning: [INFRASTRUCTURE](./INFRASTRUCTURE.md)
- Existing docs index and runbooks: [INDEX](./INDEX.md)
- **YARP Gateway**: reverse proxy layer routing traffic to service clusters.
- **Profile**: compose-scoped activation unit for selective stack bring-up.
- **Smoke Test**: scripted health and endpoint verification for essential platform services.

## Operational Notes
- Compose files include broad host port exposure; avoid conflicts with already-running local services.
- Gateway address defaults can be overridden via environment variables (`*_CLUSTER_ADDRESS`).
- Observability stack is optional for minimal testing but required for end-to-end telemetry workflows.
