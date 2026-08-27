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

Apply the Comms Configuration credential, wait for External Secrets to render
it, then apply the Telegram trust boundary and authenticated Configuration
client settings. Apply the Comms UI public origin before deploying its image:

```bash
kubectl apply --filename comms/external-secret.yaml
kubectl apply --filename comms/data-protection-pvc.yaml
# The ExternalSecret reads the Data Protection certificate and private key from
# OpenBao path secret/data/services/comms/data-protection; no PEM material is stored in Git.
kubectl apply --filename comms/service.yaml
kubectl wait --namespace nem-apps --for=condition=Ready \
  externalsecret/nem-comms-configuration-secret
kubectl patch deployment nem-comms \
  --namespace nem-apps \
  --type strategic \
  --patch-file comms/runtime-env-patch.yaml
kubectl patch deployment nem-web-comms \
  --namespace nem-apps \
  --type strategic \
  --patch-file web-comms/runtime-env-patch.yaml
kubectl rollout status deployment/nem-comms --namespace nem-apps
kubectl rollout status deployment/nem-web-comms --namespace nem-apps
```

Persist MediaHub uploads in MinIO/S3 without storing credentials in Git. Copy
the existing MinIO credentials into a namespace-local Secret, then apply the
runtime patch. The patch removes only the obsolete `smb-ugp` mount and volume;
it does not modify the `nem-mediahub-uploads` PVC.

```bash
kubectl get secret minio-creds --namespace platform-data --output json |
  jq '{
    apiVersion: "v1",
    kind: "Secret",
    metadata: {name: "nem-mediahub-s3-secrets", namespace: "nem-apps"},
    type: "Opaque",
    data: {AccessKey: .data.MINIO_ROOT_USER, SecretKey: .data.MINIO_ROOT_PASSWORD}
  }' | kubectl apply --filename -
kubectl patch deployment nem-mediahub \
  --namespace nem-apps \
  --type strategic \
  --patch-file mediahub/runtime-env-patch.yaml
kubectl rollout status deployment/nem-mediahub --namespace nem-apps
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

Reconcile the audience emitted for `nem-web` browser access tokens before using
MCP administration routes. MCP validates the `realm-management` audience before
applying the `FederationAdmin` policy.

```bash
./scripts/reconcile-keycloak-client-audience.sh
```

Reconcile the Comms service account claims used for authenticated Configuration
reads. The client keeps its existing `nem-configuration` audience and also emits
the `realm-management` audience required by the Configuration API, plus the
default production tenant claim.

```bash
KEYCLOAK_CLIENT_ID=nem-comms-configuration \
KEYCLOAK_AUDIENCE=realm-management \
KEYCLOAK_AUDIENCE_MAPPER_NAME=audience-realm-management \
KEYCLOAK_CLAIM_NAME=tenant_id \
KEYCLOAK_CLAIM_VALUE=00000000-0000-0000-0000-000000000001 \
KEYCLOAK_CLAIM_MAPPER_NAME=tenant-id \
KEYCLOAK_REALM_ROLE=service \
./scripts/reconcile-keycloak-client-audience.sh
```
