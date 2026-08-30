# Production service overlays

These manifests capture production-only configuration for services that are not yet managed by a single root Kustomization.

## RabbitMQ production service

`rabbitmq/` declaratively owns the existing `platform-data/rabbitmq` Service,
including its management and Prometheus exporter ports. Apply it independently
because the production overlays do not yet have a shared root Kustomization:

```bash
kubectl apply --kustomize rabbitmq
```

Prometheus scrapes the exporter at `/metrics/per-object` through the in-cluster
Service DNS name. The per-object endpoint is required for queue-specific labels;
the default `/metrics` endpoint aggregates queue depth across the broker.

## Comms production promotion and rollback

`comms/runtime-env-patch.yaml` and `comms/build-inputs.lock` are the production
build inputs. Promote a Comms commit by changing only its
`localhost/nem.comms:<commit-sha>` image pin on infrastructure `main`; the tag
must be 7--40 lowercase hexadecimal commit characters and resolve uniquely to a
commit on `nem.Comms` `main`. When a shared build sibling changes, promote its
full 40-character reviewed commit SHA in `build-inputs.lock` at the same time.
The trusted workflow checks out infrastructure `main`, resolves and detaches the
exact Comms commit locally, checks out every locked sibling SHA, then builds
natively on the production ARM64 runner with Buildah and imports the local image
into k3s containerd.

The production runner must be a protected self-hosted `linux`, `ARM64`,
`nem-production` runner with Buildah, curl, passwordless sudo, and k3s (the
script uses `sudo k3s kubectl`, not a standalone kubectl binary).
It must have the sibling `nem.Comms`, `nem.Contracts`, `nem.Plugins.Sdk`, and
`nem.Configuration` checkouts available in the build workspace. No credentials
belong in this repository or workflow.

For an operator-run deployment on that host, run:

```bash
./k8s/overlays/k3s-prod/services/scripts/deploy-comms.sh \
  --workspace-root /path/to/workspace \
  --source-ref <pinned-commit-sha>
```

Use `--dry-run` to print every mutating command without building, importing,
checking out source, cleaning archives, or touching the cluster. The script
uses `sudo k3s kubectl`, validates every sibling against the lock, verifies
rollout replicas, image pin, non-increasing restart count, `/health` 200, and
the unauthenticated `/api/v1/operator/inbox` endpoint 401 through a local
port-forward (default local port `15280`; override with `NEM_COMMS_LOCAL_PORT`).
Once it patches the deployment, every failure automatically restores the
previous live image and rewrites the checked-out manifest pin. The workflow
commits that restored pin only when that single patch file changed. Test the
rollback path without a production fault by setting
`NEM_DEPLOY_INJECT_FAILURE=after-patch`.

Apply and verify the Configuration authorization settings:

```bash
kubectl patch deployment nem-configuration \
  --namespace nem-apps \
  --type strategic \
  --patch-file configuration/runtime-env-patch.yaml
kubectl rollout status deployment/nem-configuration --namespace nem-apps
```

Apply the Comms Configuration credential, wait for External Secrets to render
it, then provision the dedicated Classification client credential directly from
Keycloak. The provisioning script writes only a Kubernetes Secret and never
prints or stores the credential in Git. Apply the Telegram trust boundary and
authenticated service-client settings afterward:

```bash
kubectl apply --filename comms/external-secret.yaml
kubectl apply --filename comms/data-protection-pvc.yaml
# The ExternalSecret reads the Data Protection certificate and private key from
# OpenBao path secret/data/services/comms/data-protection; no PEM material is stored in Git.
kubectl apply --filename comms/service.yaml
kubectl wait --namespace nem-apps --for=condition=Ready \
  externalsecret/nem-comms-configuration-secret
../../../../scripts/provision-comms-classification-secret.sh
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

Apply the Classification issuer, internal OIDC metadata endpoint, and strict API
audience together. The split keeps issuer validation aligned with externally
issued tokens while fetching discovery and JWKS over cluster-internal HTTP:

```bash
kubectl patch deployment nem-classification \
  --namespace nem-apps \
  --type strategic \
  --patch-file classification/runtime-env-patch.yaml
kubectl rollout status deployment/nem-classification --namespace nem-apps
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
