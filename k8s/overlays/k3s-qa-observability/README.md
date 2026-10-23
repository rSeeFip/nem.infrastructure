# QA observability (.172)

This overlay adds Loki and the OTLP logs pipeline to the QA `monitoring` namespace without replacing Prometheus, Tempo or application images. Loki uses the existing local-path storage class (2 GiB PVC), 72-hour retention, a 2 MiB/s ingestion limit and a 4 MiB burst. Only existing OTLP application logs are routed; container-log collection and longer retention require a separate capacity and redaction review.

The collector has a shared file-storage PVC. Save its ConfigMap and Deployment before updating it, switch its strategy to `Recreate` before applying the new ConfigMap, and restart the collector after Loki is ready:

```bash
kubectl kustomize k8s/overlays/k3s-qa-observability | kubectl apply --dry-run=server -f -
kubectl -n monitoring patch deployment otel-collector --type=merge \
  -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
kubectl apply -k k8s/overlays/k3s-qa-observability
kubectl -n monitoring rollout status deployment/loki --timeout=120s
kubectl -n monitoring rollout restart deployment/otel-collector
kubectl -n monitoring rollout status deployment/otel-collector --timeout=120s
```

The application Deployment patches are separate because this Kustomization sets `namespace: monitoring` and must not rewrite `nem-apps` resources. Both are image-free and contain only nonsecret environment settings. The InferenceGateway token endpoint deliberately uses the **QA** Keycloak issuer; never apply it to production.

```bash
kubectl -n nem-apps patch deployment nem-comms --type=strategic \
  --patch-file k8s/overlays/k3s-qa-observability/comms-observability-patch.yaml --dry-run=server -o name
kubectl -n nem-apps patch deployment nem-inferencegateway --type=strategic \
  --patch-file k8s/overlays/k3s-qa-observability/inferencegateway-observability-patch.yaml --dry-run=server -o name
kubectl -n nem-apps patch deployment nem-comms --type=strategic \
  --patch-file k8s/overlays/k3s-qa-observability/comms-observability-patch.yaml
kubectl -n nem-apps patch deployment nem-inferencegateway --type=strategic \
  --patch-file k8s/overlays/k3s-qa-observability/inferencegateway-observability-patch.yaml
kubectl -n nem-apps rollout status deployment/nem-comms --timeout=180s
kubectl -n nem-apps rollout status deployment/nem-inferencegateway --timeout=180s
```

Before the pilot, root-only snapshots were saved on QA: `/var/backups/nem-qa-observability-20261022T165444Z` for the collector and Comms, and `/var/backups/nem-qa-inferencegateway-healthy-20261022T181050Z` for InferenceGateway with the corrected QA issuer but before its OTLP settings. If the collector pipeline fails, restore the saved ConfigMap and restart the collector. Keep Loki's PVC unless deletion is separately approved. If InferenceGateway's telemetry settings fail, remove only its five `Observability__*` and `OTEL_*` additions; preserve the QA `NemConfiguration__TokenEndpoint` correction.

Comms QA: 20 controlled `GET /health` requests returned HTTP 200. Prometheus had HTTP request-duration metrics; two sampled IDs appeared in Tempo with `service.name=nem.Comms.Api`, each matched by 17 Loki records with the same structured `trace_id` and `service_name`.

InferenceGateway QA: a restart originally exposed a 401 from the configuration API because its token endpoint used the production Keycloak issuer while the QA configuration API trusted the dev issuer. Switching only the nonsecret token endpoint to the dev issuer restored readiness without reading or rotating credentials. After OTLP settings were added, 20 controlled `GET /health` requests returned HTTP 200. Prometheus had InferenceGateway HTTP metrics; two sampled IDs appeared in Tempo as `nem.InferenceGateway.Api` and each matched six identified Loki records by trace ID. The running images have not been rebuilt with the shared `nem.Contracts.AspNetCore` Serilog source change; explicit runtime service identity is the verified mechanism.

These checks prove telemetry for safe health requests, not authenticated business operations, alert delivery, sensitive-field redaction across every workload, or fleet-wide coverage. No log bodies or credential values are retained here.
