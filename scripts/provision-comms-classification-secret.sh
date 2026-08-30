#!/usr/bin/env bash
set -euo pipefail

namespace=${NAMESPACE:-nem-apps}
keycloak_namespace=${KEYCLOAK_NAMESPACE:-platform-identity}
keycloak_url=${KEYCLOAK_URL:-}
realm=${KEYCLOAK_REALM:-nem}
client_id=${KEYCLOAK_CLIENT_ID:-nem-comms-classification}
audience=${KEYCLOAK_AUDIENCE:-nem-classification}
secret_name=${KUBERNETES_SECRET_NAME:-nem-comms-classification-secret}
secret_key=${KUBERNETES_SECRET_KEY:-client-secret}

if [[ -z "$keycloak_url" ]]; then
  keycloak_host=$(kubectl get service keycloak \
    --namespace "$keycloak_namespace" \
    --output jsonpath='{.spec.clusterIP}')
  keycloak_port=$(kubectl get service keycloak \
    --namespace "$keycloak_namespace" \
    --output jsonpath='{.spec.ports[0].port}')
  keycloak_url="http://$keycloak_host:$keycloak_port/auth"
fi

admin_password=$(kubectl get secret keycloak-runtime \
  --namespace "$keycloak_namespace" \
  --output jsonpath='{.data.admin-password}' | base64 --decode)

admin_token=$(printf '%s' "$admin_password" | curl --fail --silent --show-error \
  --data-urlencode grant_type=password \
  --data-urlencode client_id=admin-cli \
  --data-urlencode username=admin \
  --data-urlencode password@- \
  "$keycloak_url/realms/master/protocol/openid-connect/token" | jq --raw-output .access_token)
test -n "$admin_token"

admin_api="$keycloak_url/admin/realms/$realm"
clients=$(curl --fail --silent --show-error \
  --get \
  --header "Authorization: Bearer $admin_token" \
  --data-urlencode "clientId=$client_id" \
  "$admin_api/clients")
client_count=$(jq 'length' <<<"$clients")
if [[ "$client_count" -ne 1 ]]; then
  printf 'Expected one Keycloak client %s, found %s.\n' "$client_id" "$client_count" >&2
  exit 1
fi

client_uuid=$(jq --raw-output '.[0].id' <<<"$clients")
mappers=$(curl --fail --silent --show-error \
  --header "Authorization: Bearer $admin_token" \
  "$admin_api/clients/$client_uuid/protocol-mappers/models")
mapper_count=$(jq --arg audience "$audience" \
  '[.[] | select(.protocolMapper == "oidc-audience-mapper" and .config["included.client.audience"] == $audience)] | length' \
  <<<"$mappers")
if [[ "$mapper_count" -ne 1 ]]; then
  printf 'Expected one %s audience mapper on %s, found %s.\n' "$audience" "$client_id" "$mapper_count" >&2
  exit 1
fi

client_secret=$(curl --fail --silent --show-error \
  --header "Authorization: Bearer $admin_token" \
  "$admin_api/clients/$client_uuid/client-secret" | jq --raw-output .value)
test -n "$client_secret"

client_secret_base64=$(printf '%s' "$client_secret" | base64 | tr -d '\n')
kubectl apply --filename - >/dev/null <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: $namespace
type: Opaque
data:
  $secret_key: $client_secret_base64
EOF

unset admin_password admin_token clients client_uuid mappers client_secret client_secret_base64 \
  client_count mapper_count keycloak_host keycloak_port
printf 'Provisioned Kubernetes secret %s/%s for Keycloak client %s.\n' \
  "$namespace" "$secret_name" "$client_id"
