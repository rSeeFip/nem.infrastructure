# Production service overlays

These manifests capture production-only configuration for services that are not yet managed by a single root Kustomization.

Apply and verify the Configuration authorization settings:

```bash
kubectl patch deployment nem-configuration \
  --namespace nem-apps \
  --type strategic \
  --patch-file configuration/runtime-env-patch.yaml
kubectl rollout status deployment/nem-configuration --namespace nem-apps
```

Apply the bounded PostgreSQL pools. External Secrets renders the connection strings from OpenBao; no database credentials are stored in Git.

```bash
kubectl apply --filename configuration/external-secret.yaml
kubectl apply --filename inferencegateway/external-secret.yaml
kubectl wait --namespace nem-apps --for=condition=Ready \
  externalsecret/nem-configuration-connection-secrets \
  externalsecret/nem-inferencegateway-connection-secrets
kubectl rollout restart deployment/nem-configuration deployment/nem-inferencegateway --namespace nem-apps
kubectl rollout status deployment/nem-configuration --namespace nem-apps
kubectl rollout status deployment/nem-inferencegateway --namespace nem-apps
```

Provision or rotate the non-human browser test identity. The generated password is written only to Kubernetes Secret `nem-apps/nem-web-e2e-credentials`.

```bash
./scripts/provision-web-e2e-user.sh
```
