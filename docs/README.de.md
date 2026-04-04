<!-- sync-hash: 478318eef43e449863647cd232c14dd6 -->
# nem.infrastructure

## Repository-Zweck
`nem.infrastructure` enthält gemeinsame Infrastrukturkonfiguration für den lokalen oder entwicklungsnahen Betrieb des nem-Ökosystems. Es zentralisiert Docker-Compose-Definitionen, Reverse-Proxy-Routing, Observability-Bereitstellung und unterstützende Bootstrap-/Smoke-Test-Skripte.

## Einrichtung
1. Docker Engine + Docker-Compose-Plugin installieren.
2. Falls nötig das erforderliche Docker-Netzwerk erstellen:

```bash
docker network create nem-network
```

3. Für einen classification-/comms-fokussierten Stack `.env.classification` vorbereiten.
4. Sicherstellen, dass Schwester-Service-Repositories existieren, wenn Compose-Dateien Images aus relativen Pfaden bauen.

## Nutzung
- Voller Shared Stack:

```bash
docker compose -f docker-compose.yml up -d
```

- Classification-/Comms-Profile-Stack:

```bash
docker compose --env-file .env.classification -f docker-compose.classification.yml --profile full-stack up -d
```

- Nur RabbitMQ-Transport:

```bash
docker compose -f docker-compose.rabbitmq.yml up -d
```

## Verifikation
- Gateway-Health-Endpunkt:

```bash
curl -f http://localhost:8090/health
```

- Full-Stack-Smoke-Test (Classification-Profil):

```bash
bash scripts/test-full-stack.sh
```

- Compose-Syntax vor dem Start validieren:

```bash
docker compose -f docker-compose.yml config >/dev/null
```

## Beitragsregeln
- Infrastruktur-Dokus und Compose-/Runtime-Dateien synchron halten; unkommentierte Route- oder Port-Änderungen vermeiden.
- Health Checks beim Ändern von Services erhalten; sie werden für automatisierte Smoke-Validierung verwendet.
- Docs-only-Commits auf `docs/`-Pfade beschränken, wenn die Aufgabe nur Dokumentation betrifft.
- Keine geheimnisbehafteten Environment-Dateien committen.

## Verzeichniskarte
- `docker-compose.yml`: Kern- + Observability-Plattform-Stack.
- `docker-compose.classification.yml`: classification/comms und zugehörige Abhängigkeiten via Profiles.
- `docker-compose.rabbitmq.yml`: eigenständiges Broker-Deployment.
- `nem.Gateway/Program.cs`: YARP-Host-Bootstrap und Env-Override-Wiring.
- `yarp-gateway.json`: Route-/Cluster-Topologie für API- und Frontend-Hostnamen.
- `prometheus/prometheus.yml`: Scrape-Topologie und Target-Labeling.
- `scripts/test-full-stack.sh`: automatisierte Readiness-Checks.

## Querverweise und Glossarverwendung
- Topologie und Deployment-Begründung: [INFRASTRUCTURE](./INFRASTRUCTURE.md)
- Vorhandener Docs-Index und Runbooks: [INDEX](./INDEX.md)
- **YARP Gateway**: Reverse-Proxy-Schicht, die Traffic an Service-Cluster routet.
- **Profile**: Compose-scoped Aktivierungseinheit für selektiven Stack-Aufbau.
- **Smoke Test**: skriptgesteuerte Health- und Endpoint-Verifikation essenzieller Plattformdienste.

## Operative Hinweise
- Compose-Dateien enthalten breite Host-Port-Freigabe; Konflikte mit bereits laufenden lokalen Services vermeiden.
- Gateway-Adress-Defaults können über Environment-Variablen (`*_CLUSTER_ADDRESS`) überschrieben werden.
- Der Observability-Stack ist für Minimaltests optional, für End-to-End-Telemetry-Workflows jedoch erforderlich.
