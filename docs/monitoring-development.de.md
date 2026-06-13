<!-- sync-hash: ecbf3f8fdfa670829e426e05b6994d01 -->
# Monitoring-Entwicklung

## Einen Service instrumentieren
Alle nem.*-Services können instrumentiert werden, indem das Paket `nem.Contracts.AspNetCore` hinzugefügt und die Registrierungs-Extensions in `Program.cs` aufgerufen werden.

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddNemOpenTelemetry(builder.Configuration);

// ... after builder.Build()
app.UseNemOpenTelemetry();
```

Um das Collection-Setup zu aktivieren, setzen Sie `Enabled: true` in `appsettings.json`:

```json
{
  "OpenTelemetry": {
    "Enabled": true,
    "ServiceName": "nem.mcp",
    "Endpoint": "http://localhost:4317"
  }
}
```

## Custom Metrics
Metriken werden verwendet, um quantitative Daten wie Counter-Werte oder Operationsdauern zu verfolgen. Verwenden Sie `System.Diagnostics.Metrics`.

```csharp
var meter = new Meter("nem.mcp.documents");
var counter = meter.CreateCounter<long>("documents_processed_total");

// In code
counter.Add(1, new TagList { { "status", "success" } });
```

`AddNemOpenTelemetry` entdeckt keine beliebigen Service-Meter automatisch. Standardmäßig registriert es den gemeinsamen `nem.platform`-Meter plus ASP.NET Core, HttpClient, Runtime- und Prometheus-Instrumentierung. Wenn Sie einen eigenen Meter hinzufügen, registrieren Sie diesen Maternamen explizit in der OpenTelemetry-Metrics-Pipeline Ihres Services.

## Custom Traces
Traces verfolgen den Pfad einer Anfrage durch das System. Verwenden Sie `System.Diagnostics.ActivitySource`.

```csharp
var source = new ActivitySource("nem.mcp");

using var activity = source.StartActivity("process-document");
activity?.SetTag("document.id", docId);

// Traces across HTTP/Wolverine are correlated automatically
```

## Ein neues Dashboard hinzufügen
Um ein neues Dashboard zum bereitgestellten Set hinzuzufügen:
1.  Exportieren Sie das JSON aus einer laufenden Grafana-Instanz.
2.  Setzen Sie in dem JSON `"id": null` und `"uid": "unique-id"`.
3.  Stellen Sie sicher, dass Datenquellen die UIDs `prometheus`, `loki` oder `tempo` verwenden.
4.  Speichern Sie die JSON-Datei unter `nem.infrastructure/grafana/dashboards/`.

Dashboards werden beim Grafana-Start über die Provisioning-Engine automatisch geladen.

## Alert-Regeln hinzufügen
Alert-Regeln sind in `nem.infrastructure/grafana/provisioning/alerting/alert-rules.yaml` definiert.

Beispielregel:
```yaml
groups:
  - name: nem-service-alerts
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
```

## Alert-Kanäle
Kanäle werden über den Benachrichtigungsservice `nem.Comms` verwaltet.
1.  `MonitoringAlertSettings` in `appsettings.json` konfigurieren.
2.  Unterstützte Kanäle definieren (Telegram, Teams, WhatsApp, Signal oder WebWidget).
3.  Regeln Kanälen basierend auf Severity-Labels zuweisen.

## Telemetry lokal testen
1.  Monitoring-Stack starten: `docker compose up -d`.
2.  Service mit `OpenTelemetry:Enabled=true` starten.
3.  Aktionen im Service ausführen, um Telemetry zu erzeugen.
4.  Daten in Grafana (http://localhost:3010) im `Explore`-Tab prüfen.
