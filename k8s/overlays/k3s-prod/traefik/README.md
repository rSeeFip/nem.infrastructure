# Traefik ingress (k3s production)

Helm values for the Traefik ingress controller running on the `nem.endorff.net`
k3s cluster. Traefik is installed as a standalone Helm release (it is **not**
managed by the k3s bundled-manifests mechanism), so this directory is the source
of truth for the release's user-supplied values.

## Why this exists

The running DaemonSet had been customised in place with two changes that were not
captured anywhere in git:

1. **Extended idle timeout** on the `websecure` entrypoint
   (`respondingTimeouts.idleTimeout=600s`). Mimir chat streams responses over
   SignalR/WebSocket (`/hubs/chat`). During slow LLM token generation the stream
   stayed idle long enough to hit Traefik's default idle timeout, closing the
   socket mid-response (close code 1006).

2. **Five dedicated TLS entrypoints** — `api` (8444), `mimir` (8445),
   `inference` (8446), `media` (8447), and `auth` (8448) — each with
   `http.tls=true`.

Because those values were only present on the live DaemonSet, any `helm upgrade`
that reused the persisted release values would have reverted them. `values.yaml`
now records the full desired state so upgrades are reproducible.

## Applying

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik

helm -n traefik upgrade traefik traefik/traefik --version 40.2.0 \
  -f k8s/overlays/k3s-prod/traefik/values.yaml
```

Traefik runs as a DaemonSet with `hostPort` 80/443. If the upgraded pod stays
`Pending` because the old pod still holds the host ports, delete the old pod to
let the rollout complete:

```bash
kubectl -n traefik delete pod -l app.kubernetes.io/name=traefik
```

## Verifying

```bash
# All entrypoints present (web, websecure, api, mimir, inference, media, auth)
# and the idle timeout applied:
kubectl -n traefik get ds traefik \
  -o jsonpath='{.spec.template.spec.containers[0].args}'

# Site reachable and the Mimir hub route still negotiates:
curl -sk -o /dev/null -w '%{http_code}\n' https://nem.endorff.net/mimir
curl -sk -o /dev/null -w '%{http_code}\n' -X POST \
  https://nem.endorff.net/hubs/chat/negotiate
```

If an upgrade misbehaves, roll back to the previous revision:

```bash
helm -n traefik rollback traefik
```
