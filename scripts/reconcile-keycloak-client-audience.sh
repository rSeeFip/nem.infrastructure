#!/usr/bin/env bash
set -euo pipefail

namespace=${NAMESPACE:-nem-apps}
keycloak_namespace=${KEYCLOAK_NAMESPACE:-platform-identity}
keycloak_url=${KEYCLOAK_URL:-}
realm=${KEYCLOAK_REALM:-nem}
client_id=${KEYCLOAK_CLIENT_ID:-nem-web}
audience=${KEYCLOAK_AUDIENCE:-realm-management}
mapper_name=${KEYCLOAK_AUDIENCE_MAPPER_NAME:-audience-realm-management}

if [[ -z "$keycloak_url" ]]; then
  keycloak_host=$(kubectl get service keycloak \
    --namespace "$keycloak_namespace" \
    --output jsonpath='{.spec.clusterIP}')
  keycloak_port=$(kubectl get service keycloak \
    --namespace "$keycloak_namespace" \
    --output jsonpath='{.spec.ports[0].port}')
  keycloak_url="http://$keycloak_host:$keycloak_port/auth"
fi

admin_password=$(kubectl get secret nem-lume-secrets \
  --namespace "$namespace" \
  --output jsonpath='{.data.Keycloak__AdminPassword}' | base64 --decode)

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
mappers_url="$admin_api/clients/$client_uuid/protocol-mappers/models"
mappers=$(curl --fail --silent --show-error \
  --header "Authorization: Bearer $admin_token" \
  "$mappers_url")

audience_filter='[.[] | select(.protocolMapper == "oidc-audience-mapper" and .config["included.client.audience"] == $audience)] | length'
mapper_count=$(jq --arg audience "$audience" "$audience_filter" <<<"$mappers")
if [[ "$mapper_count" -gt 1 ]]; then
  printf 'Expected at most one %s audience mapper on %s, found %s.\n' "$audience" "$client_id" "$mapper_count" >&2
  exit 1
fi

if [[ "$mapper_count" -eq 0 ]]; then
  mapper_body=$(jq --null-input \
    --arg name "$mapper_name" \
    --arg audience "$audience" \
    '{
      name: $name,
      protocol: "openid-connect",
      protocolMapper: "oidc-audience-mapper",
      consentRequired: false,
      config: {
        "included.client.audience": $audience,
        "id.token.claim": "false",
        "access.token.claim": "true"
      }
    }')
  response_code=$(printf '%s' "$mapper_body" | curl --silent --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --request POST \
    --header "Authorization: Bearer $admin_token" \
    --header 'Content-Type: application/json' \
    --data-binary @- \
    "$mappers_url")
  if [[ "$response_code" != 201 && "$response_code" != 204 ]]; then
    printf 'Keycloak audience mapper creation failed with HTTP %s.\n' "$response_code" >&2
    exit 1
  fi
fi

verified_mappers=$(curl --fail --silent --show-error \
  --header "Authorization: Bearer $admin_token" \
  "$mappers_url")
verified_count=$(jq --arg audience "$audience" "$audience_filter" <<<"$verified_mappers")
if [[ "$verified_count" -ne 1 ]]; then
  printf 'Expected one verified %s audience mapper on %s, found %s.\n' "$audience" "$client_id" "$verified_count" >&2
  exit 1
fi

unset admin_password admin_token mapper_body clients mappers verified_mappers \
  client_uuid client_count mapper_count verified_count response_code keycloak_host keycloak_port
printf 'Reconciled Keycloak client %s audience %s.\n' "$client_id" "$audience"
