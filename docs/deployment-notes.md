# Deployment Notes

## PostgreSQL port conflict

The shared workspace already runs a PostgreSQL instance on port `5432`, which conflicts with the `nem-postgres` container in `docker-compose.yml`.

### Resolution

Set `POSTGRES_PORT=5433` in your local `.env` file to publish the container on a different host port:

```env
POSTGRES_PORT=5433
```

The compose file uses `POSTGRES_PORT` with a default of `5432`, so the override is only needed when the default host port is unavailable.

### Other known port conflicts

- `5432` — workspace PostgreSQL vs. `nem-postgres`
- `8080` — Keycloak
- `8090` — Gateway
- `9090` — Prometheus
- `3010` — Grafana

Adjust the relevant host port variables if any of these are already occupied in your environment.
