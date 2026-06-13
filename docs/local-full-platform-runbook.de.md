<!-- sync-hash: bfda2e94603ba58a56a8de82bef240a5 -->
# Local Full Platform Runbook (wmreflect)

Dieses Runbook beschreibt den bekannten guten lokalen Bring-up-Flow für das vollständige `nem.*`-Ökosystem mit der einheitlichen Compose-Datei unter:

- `/workspace/wmreflect/docker-compose.yml`

## 1) Voraussetzungen

- Docker Engine + Docker-Compose-Plugin installiert
- Mindestens 12 GB RAM für Docker verfügbar
- Folgende Host-Ports verfügbar: `3000`, `3010`, `5002-5005`, `5010-5011`, `5020`, `5050`, `5100`, `5223`, `5432`, `5672`, `8080`, `8090`, `9090`, `15672`

## 2) Erstmaliger Bring-up

Aus `/workspace/wmreflect` ausführen:

```bash
docker compose build
docker compose up -d
```

## 3) Health-Verifikation

```bash
docker compose ps -a
```

Erwartete wesentliche gesunde Services:

- Core Apps: `nem-mcp`, `nem-knowhub`, `nem-holisticworld`, `nem-assetcore`, `nem-mediahub`, `nem-mimir`, `nem-scheduler`, `nem-web`
- Adapter: `nem-teams-adapter`, `nem-whatsapp-adapter`, `nem-signal-adapter`
- Infra: `postgres`, `rabbitmq`, `keycloak`, `gateway`, `otel-collector`, `grafana`, `prometheus`, `loki`, `tempo`, `pgadmin`

## 4) Schnelle Host-URL-Referenz

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

Port-Mapping kann jederzeit erneut geprüft werden mit:

```bash
docker compose port <service> <container-port>
```

## 5) Datenbankhinweise

Der Stack beruht auf PostgreSQL-Datenbanken für mehrere Services. Wenn ein persistiertes Volume verwendet wird, sicherstellen, dass die benötigten DBs existieren:

- `mcp`, `knowhub`, `mimir`, `scheduler`, `assetcore`, `holisticworld`, `keycloak`

Für KnowHub Vector Search sicherstellen, dass pgvector verfügbar und aktiviert ist:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## 6) Bekanntes lokales Verhalten

- `nem-signal-adapter` kann gesund sein, während signal-cli-API-Retries weiter in den Logs laufen, falls der API-Endpunkt lokal nicht verfügbar ist.
- Die Health-Prüfung von `nem-knowhub` sollte `/api/v1/health/embedding` für stabile Readiness in diesem Compose-Profil abfragen.

## 7) Schnelle Troubleshooting-Kommandos

```bash
# Service-Logs
docker compose logs -f nem-knowhub

# Einen Service neu bauen
docker compose build nem-knowhub

# Einen Service hart neu erstellen
docker compose up -d --force-recreate nem-knowhub

# Health-JSON inspizieren
docker inspect --format '{{json .State.Health}}' nem-knowhub
```

## 8) Gesamte Plattform herunterfahren

```bash
docker compose down
```

Optionales Cleanup (entfernt auch benannte Volumes):

```bash
docker compose down -v
```
