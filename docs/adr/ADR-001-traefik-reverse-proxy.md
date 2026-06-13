# ADR-001: Traefik as Reverse Proxy and TLS Terminator

**Date**: 2024-12-01
**Status**: Accepted

## Context

The nem* ecosystem requires a reverse proxy to route traffic to multiple services, handle TLS termination, and provide service discovery. Options considered: Nginx, Caddy, Traefik.

## Decision

Use Traefik v3 as the reverse proxy. Traefik's native Docker and Kubernetes provider support enables automatic service discovery via container labels, eliminating manual routing configuration.

## Consequences

### Positive
- Zero-config service discovery via Docker labels
- Automatic TLS via Let's Encrypt (ACME)
- Built-in dashboard for routing visibility

### Negative
- Traefik v3 has breaking changes from v2; migration required
- Dynamic configuration can be harder to reason about than static Nginx config

### Neutral
- Traefik dashboard is exposed on port 8080 (internal only)
