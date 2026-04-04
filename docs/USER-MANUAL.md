# User Manual — nem.infrastructure

## Audience

This manual is for **developers** and **operators** who work with `nem.infrastructure`, which provides shared Docker Compose configurations, reverse proxy setup, and infrastructure tooling for the nem.* platform.

### Intended Readers

- **Developers**: Engineers integrating with or extending the service
- **Operators**: Platform team members responsible for deployment and monitoring
- **Architects**: Technical leads reviewing integration patterns

## Getting Started

### Prerequisites

- .NET 10 SDK installed
- Docker and Docker Compose for local development
- Access to the nem.* platform network and authentication credentials

### Installation

Clone the repository and restore dependencies:

```bash
cd nem.infrastructure
dotnet restore nem.infrastructure.slnx
dotnet build nem.infrastructure.slnx
```

### Configuration

Service configuration follows the nem.* convention using `IConfigurationManager`:

- Environment-specific settings in `appsettings.{Environment}.json`
- Secrets managed through OpenBao (Vault fork)
- Runtime configuration editable through nem.MCP administration UI

## Core Workflows

### Primary Use Cases

The service supports the following primary workflows:

1. **Service Integration**: Connecting to the service via its API endpoints
2. **Configuration Management**: Adjusting service behavior through configuration
3. **Monitoring**: Observing service health and performance metrics

### API Access

All API endpoints require authentication via Keycloak JWT tokens. Standard headers:

```
Authorization: Bearer <jwt-token>
Content-Type: application/json
```

### Health Checks

Verify service health:

```bash
curl http://localhost:<port>/health
```

## Troubleshooting

### Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Connection refused | Service not running | Verify Docker container status with `docker compose ps` |
| 401 Unauthorized | Invalid or expired token | Refresh Keycloak token or check audience claim |
| 500 Internal Error | Configuration issue | Check service logs via `docker compose logs nem.infrastructure` |

### Log Access

Structured logs are available via Serilog and OpenTelemetry:

```bash
docker compose logs -f <service-name>
```

### Support Channels

- Platform documentation: nem.MCP administration portal
- Issue tracking: Repository issue tracker
- Team communication: Standard platform channels

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — System design and component overview
- [QA.md](./QA.md) — Quality assurance and testing strategy
