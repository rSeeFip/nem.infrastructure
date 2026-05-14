# nem.infrastructure

Infrastructure configuration for the nem* ecosystem. Contains Docker Compose files, Kubernetes manifests, Traefik routing, and deployment scripts for the full nem* platform stack.

## Purpose

nem.infrastructure provides the deployment substrate for all nem* services:
- **Docker Compose**: Local development and staging environment
- **Kubernetes**: Production deployment manifests (Kustomize overlays)
- **Traefik**: Reverse proxy and TLS termination configuration
- **OpenBao/Vault**: Secrets management policies
- **Certificates**: TLS certificate management (cert-manager)

## Prerequisites

- Docker 24+ with Docker Compose v2
- kubectl + kustomize (for Kubernetes deployments)
- Helm 3+ (for chart-based deployments)
- OpenBao/Vault CLI (for secrets management)

## Quick Start

```bash
cd nem.infrastructure

# Start full local stack
docker compose up -d

# Check service health
docker compose ps

# View logs
docker compose logs -f nem-api
```

## Structure

```
nem.infrastructure/
├── docker-compose.yml        # Full stack local development
├── .env.example              # Environment variable template
├── k8s/
│   ├── base/                 # Base Kubernetes manifests
│   └── overlays/
│       ├── staging/          # Staging environment overrides
│       └── production/       # Production environment overrides
├── traefik/
│   ├── traefik.yml           # Traefik static config
│   └── dynamic/              # Dynamic routing rules
├── openbao/
│   └── policies/             # Vault/OpenBao access policies
└── certs/
    └── cert-manager/         # cert-manager ClusterIssuer configs
```

## Service Catalog

| Service | Port | Image | Purpose |
|---------|------|-------|---------|
| PostgreSQL | 5432 | postgres:17 | Primary datastore |
| RabbitMQ | 5672 | rabbitmq:3-management | AMQP broker |
| Keycloak | 8080 | keycloak:26.0 | OIDC/JWT |
| OPA | 8181 | opa:latest | Policy engine |
| OpenBao | 8200 | openbao:latest | Secrets management |
| Gateway | 8090 | nem.Gateway | YARP reverse proxy |

## Port Conflict Resolution

If port 5432 conflicts with a local PostgreSQL instance:

```bash
# Copy .env.example to .env and override
cp .env.example .env
# Edit .env: POSTGRES_PORT=5433
docker compose up -d
```

## Observability Stack

- **Prometheus**: Metrics time-series DB (Port 9090)
- **Loki**: Logs aggregation (Port 3100)
- **Tempo**: Traces (Port 3200)
- **Grafana**: Dashboards (Port 3010)

## Deployment

See [docs/deployment.md](docs/deployment.md) for full deployment runbook including:
- Kubernetes cluster setup
- Secrets injection via OpenBao
- TLS certificate provisioning
- ArgoCD application registration

## Contributing

Infrastructure changes require review from platform team. No application code lives here.
