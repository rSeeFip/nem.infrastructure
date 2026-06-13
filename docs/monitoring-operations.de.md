<!-- sync-hash: 3f124727da8a8948bfc6af6ca9d80fdc -->
# Monitoring-Betrieb

## Schnellstart
Um den Monitoring-Stack lokal zu starten, führen Sie im Verzeichnis `nem.infrastructure/` Folgendes aus:

```bash
docker compose up -d
```

Dies startet alle LGTM-Komponenten (Loki, Grafana, Tempo, Prometheus) sowie die in diesem Stack enthaltenen Exporter.

## Zugriff auf Grafana
Grafana ist das zentrale Portal für alle Monitoring-Daten.

*   **URL**: [http://localhost:3010](http://localhost:3010)
*   **Credentials**: `admin` / `admin` (Default)
*   **Default Dashboards**: beim Start provisioniert.

## Dashboard-Leitfaden
Folgende Kern-Dashboards sind im Menü `Dashboards` verfügbar:

1.  **Infrastructure Overview**: zeigt Systemgesundheit, Container-Ressourcennutzung (CPU/Speicher) und Datenbank-/Container-Sichtbarkeit. Metriken stammen von `cadvisor` und `postgres-exporter`.
2.  **RED Metrics**: zeigt Rate, Error und Duration für alle instrumentierten Services. Enthält Quantilverteilungen (P50, P90, P99) und Trends der Fehlerrate.
3.  **Log Explorer**: eine spezialisierte Ansicht zum Suchen und Filtern von Logs aus Loki. Filter nach `service_name`, `level` oder bestimmten Message-Inhalten via LogQL.
4.  **Trace Explorer**: bietet Trace-Suche und Visualisierung. Ermöglicht das Finden langsamer Requests, das Anzeigen von Call-Hierarchien und das Inspizieren von von Tempo erzeugten Service Maps.

## Alert-Management
Alerts werden über Grafana Alerting verwaltet und per YAML-Dateien provisioniert.

### Zentrale Alert-Regeln
*   **service-down**: wird ausgelöst, wenn `up == 0` länger als 2 Minuten gilt. Kritische Severity.
*   **error-rate-spike**: wird ausgelöst, wenn die 5xx-HTTP-Fehlerrate 5 % für 5 Minuten überschreitet. Warning Severity.

### Alert-Routing
Alerts werden an den Webhook `nem.Comms` geroutet, der an konfigurierte unterstützte Kanäle wie Telegram, Teams, WhatsApp, Signal oder WebWidget weiterleitet.

## Fehlerbehebung
*   **Service fehlt in Prometheus**: Prüfen, ob der Service läuft und `Enabled: true` in `appsettings.json` gesetzt ist. Sicherstellen, dass der `/metrics`-Endpunkt erreichbar ist.
*   **Keine Logs in Loki**: Sicherstellen, dass OTLP-Logging aktiviert ist und der OTEL Collector auf Port 4317 erreichbar ist. Collector-Logs auf Exportfehler prüfen.
*   **Keine Traces in Tempo**: Prüfen, ob `ActivitySource`-Namen mit dem konfigurierten Servicenamen übereinstimmen. Traces werden gebündelt; es kann 5–10 Sekunden dauern, bis sie erscheinen.
*   **Grafana-Dashboards leer**: Sicherstellen, dass die Datenquellen (Prometheus, Loki, Tempo) im Menü `Connections > Data Sources` gesund sind.

## Stack-Verwaltung
Kommandos zur Verwaltung der Monitoring-Infrastruktur:

```bash
# Stack starten
docker compose up -d

# Container stoppen und entfernen
docker compose down

# Logs für eine bestimmte Komponente anzeigen
docker compose logs -f otel-collector

# Komponente nach Konfigurationsänderung neu starten
docker compose restart prometheus
```
