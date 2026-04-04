<!-- sync-hash: 7efbb867ede5618bfa74bc502d611446 -->
# Monitoring-Architektur

## Überblick
Das nem.*-Ökosystem verwendet den LGTM-Stack (Loki, Grafana, Tempo, Prometheus) für Observability. Diese moderne Observability-Suite ersetzt Legacy-Tools wie Jaeger durch eine einheitliche, performante Telemetry-Pipeline.

Der Stack liefert einen ganzheitlichen Blick auf das System, indem er die drei Säulen der Observability korreliert:
*   **Metriken**: quantitative Daten über Service-Gesundheit und Performance (Prometheus).
*   **Logs**: diskrete Events, die von Services emittiert werden (Loki).
*   **Traces**: End-to-End-Request-Flows über Microservices hinweg (Tempo).

## Komponentenarchitektur
Telemetry-Daten fließen von Anwendungen über einen zentralen Collector zu spezialisierten Backends:

```text
[ .NET Services ] --(OTLP)--> [ OTEL Collector ]
                                     |
         +---------------------------+---------------------------+
         |                           |                           |
  [ Prometheus ]               [ Loki ]                  [ Tempo ]
    (Metrics)                   (Logs)                   (Traces)
         |                           |                           |
         +---------------------------+---------------------------+
                                     |
                                [ Grafana ]
                            (Visualization)
```

## Komponentenbeschreibungen
*   **OTEL Collector**: Der zentrale Telemetry-Hub. Er empfängt OTLP-Daten via gRPC/HTTP, verarbeitet sie und exportiert sie an die passenden Backends.
*   **Prometheus**: Speichert Zeitreihenmetriken. Es scrapt Targets und bietet eine mächtige Query-Sprache (PromQL).
*   **Loki**: Ein horizontal skalierbares, hochverfügbares Log-Aggregationssystem. Es indexiert Metadaten statt vollständiger Log-Zeilen für Effizienz (LogQL).
*   **Tempo**: Ein Distributed-Tracing-Backend für hohe Volumina. Es speichert Trace-Daten und erlaubt tiefe Inspektion von Request-Spans (TraceQL).
*   **Grafana OSS**: Die einheitliche Visualisierungsschicht, die an alle Backends angebunden ist, um integrierte Dashboards und Alerting bereitzustellen.

## Port-Mapping
Alle Monitoring-Services laufen im internen `nem-network`.

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| OTEL Collector gRPC | 4317 | OTLP/gRPC | Primary telemetry ingest |
| OTEL Collector HTTP | 4318 | OTLP/HTTP | Web/Frontend telemetry ingest |
| OTEL Collector Health | 13133 | HTTP | Readiness/Liveness probes |
| OTEL Collector Prom | 8889 | HTTP | Internal collector metrics |
| Prometheus | 9090 | HTTP | Metrics query API & UI |
| Loki | 3100 | HTTP | Log ingest & query API |
| Tempo | 3200 | HTTP | Trace ingest & query API |
| Grafana | 3010 | HTTP | Web UI (Mapped from 3000) |
| postgres-exporter | 9187 | HTTP | Database metrics |
| cadvisor | 8085 | HTTP | Container/Host metrics |

## Datenfluss
1.  **Instrumentation**: .NET-Services verwenden `OpenTelemetry` SDKs, um Signale zu emittieren.
2.  **Übertragung**: Signale werden via OTLP an `nem-otel-collector:4317` gesendet.
3.  **Verarbeitung**: Der Collector bündelt und wiederholt Exports an Backends.
4.  **Speicherung**:
    *   Metriken gehen via remote-write oder Scraping an Prometheus.
    *   Logs werden an Loki gepusht.
    *   Traces werden an Tempo gepusht.
5.  **Visualisierung**: Grafana fragt diese Backends ab, um Dashboards zu rendern.

## Retention Policies
Retention ist so konfiguriert, dass Sichtbarkeit und Speicherkosten ausbalanciert werden:
*   **Prometheus**: 30 Tage (`--storage.tsdb.retention.time=30d`)
*   **Loki**: 14 Tage (`retention_period: 336h`)
*   **Tempo**: 7 Tage (`block_retention: 168h`)

## Konfigurationsdateien
*   `nem.infrastructure/docker-compose.yml`: Service-Definitionen und Port-Maps.
*   `nem.infrastructure/otel-collector/otel-collector-config.yaml`: Pipeline-Definitionen.
*   `nem.infrastructure/prometheus/prometheus.yml`: Scrape-Jobs und Alerting.
*   `nem.infrastructure/loki/loki-config.yaml`: Log-Speicher und Retention.
*   `nem.infrastructure/tempo/tempo-config.yaml`: Trace-Speicher und Retention.
*   `nem.infrastructure/grafana/grafana.ini`: Server- und Security-Einstellungen.
