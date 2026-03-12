# Monitoring Development

## Instrumenting a Service
All nem.* services can be instrumented by adding the `nem.Contracts.AspNetCore` package and calling the registration extensions in `Program.cs`.

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddNemOpenTelemetry(builder.Configuration);

// ... after builder.Build()
app.UseNemOpenTelemetry();
```

To enable collection, set `Enabled: true` in `appsettings.json`:

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
Metrics are used to track quantitative data like counter values or operation durations. Use `System.Diagnostics.Metrics`.

```csharp
var meter = new Meter("nem.mcp.documents");
var counter = meter.CreateCounter<long>("documents_processed_total");

// In code
counter.Add(1, new TagList { { "status", "success" } });
```

`AddNemOpenTelemetry` does not auto-discover arbitrary service meters. By default it registers the shared `nem.platform` meter plus ASP.NET Core, HttpClient, runtime, and Prometheus instrumentation. If you add a custom meter, register that meter name explicitly in your service's OpenTelemetry metrics pipeline.

## Custom Traces
Traces track the path of a request through the system. Use `System.Diagnostics.ActivitySource`.

```csharp
var source = new ActivitySource("nem.mcp");

using var activity = source.StartActivity("process-document");
activity?.SetTag("document.id", docId);

// Traces across HTTP/Wolverine are correlated automatically
```

## Adding a New Dashboard
To add a new dashboard to the provisioned set:
1.  Export the JSON from a running Grafana instance.
2.  Set `"id": null` and `"uid": "unique-id"` in the JSON.
3.  Ensure data sources use UIDs `prometheus`, `loki`, or `tempo`.
4.  Save the JSON file to `infrastructure/grafana/dashboards/`.

Dashboards are auto-loaded on Grafana startup via the provisioning engine.

## Adding Alert Rules
Alert rules are defined in `infrastructure/grafana/provisioning/alerting/alert-rules.yaml`.

Example rule definition:
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

## Alert Channels
Channels are managed via the `nem.Comms` notification service.
1.  Configure `MonitoringAlertSettings` in `appsettings.json`.
2.  Define supported channels (Telegram, Teams, WhatsApp, Signal, or WebWidget).
3.  Assign rules to channels based on severity labels.

## Testing Telemetry Locally
1.  Run the monitoring stack: `docker compose up -d`.
2.  Start your service with `OpenTelemetry:Enabled` set to `true`.
3.  Perform actions in your service to generate telemetry.
4.  Verify data in Grafana (http://localhost:3010) using the `Explore` tab.
