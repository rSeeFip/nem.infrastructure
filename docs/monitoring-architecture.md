# Monitoring Architecture

## Overview
The nem.* ecosystem uses the LGTM stack (Loki, Grafana, Tempo, Prometheus) for observability. This modern observability suite replaces legacy tools like Jaeger with a unified, high-performance telemetry pipeline.

The stack provides a holistic view of the system by correlating the three pillars of observability:
*   **Metrics**: Quantitative data about service health and performance (Prometheus).
*   **Logs**: Discrete events emitted by services (Loki).
*   **Traces**: End-to-end request flows across microservices (Tempo).

## Component Architecture
Telemetry data flows from applications through a central collector to specialized backends:

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

## Component Descriptions
*   **OTEL Collector**: The central telemetry hub. It receives OTLP data via gRPC/HTTP, processes it, and exports it to the appropriate backends.
*   **Prometheus**: Stores time-series metrics. It scrapes targets and provides a powerful query language (PromQL).
*   **Loki**: A horizontally scalable, highly available log aggregation system. It indexes metadata rather than full log lines for efficiency (LogQL).
*   **Tempo**: A high-volume distributed tracing backend. It stores trace data and allows for deep inspection of request spans (TraceQL).
*   **Grafana OSS**: The unified visualization layer that connects to all backends to provide integrated dashboards and alerting.

## Port Mapping
All monitoring services run on the internal `nem-network`.

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

## Data Flow
1.  **Instrumentation**: .NET services use `OpenTelemetry` SDKs to emit signals.
2.  **Transmission**: Signals are sent via OTLP to `nem-otel-collector:4317`.
3.  **Processing**: The collector batches and retries exports to backends.
4.  **Storage**: 
    *   Metrics go to Prometheus via remote-write or scraping.
    *   Logs are pushed to Loki.
    *   Traces are pushed to Tempo.
5.  **Visualization**: Grafana queries these backends to render dashboards.

## Retention Policies
Retention is configured to balance visibility with storage costs:
*   **Prometheus**: 30 days (`--storage.tsdb.retention.time=30d`)
*   **Loki**: 14 days (`retention_period: 336h`)
*   **Tempo**: 7 days (`block_retention: 168h`)

## Configuration Files
*   `nem.infrastructure/docker-compose.yml`: Service definitions and port maps.
*   `nem.infrastructure/otel-collector/otel-collector-config.yaml`: Pipeline definitions.
*   `nem.infrastructure/prometheus/prometheus.yml`: Scrape jobs and alerting.
*   `nem.infrastructure/loki/loki-config.yaml`: Log storage and retention.
*   `nem.infrastructure/tempo/tempo-config.yaml`: Trace storage and retention.
*   `nem.infrastructure/grafana/grafana.ini`: Server and security settings.
