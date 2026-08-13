#!/usr/bin/env bash
set -euo pipefail

namespace=${NAMESPACE:-nem-apps}
keycloak_namespace=${KEYCLOAK_NAMESPACE:-platform-identity}
keycloak_url=${KEYCLOAK_URL:-}
realm=${KEYCLOAK_REALM:-nem}
username=${E2E_USERNAME:-nem-e2e-admin}
secret_name=${E2E_SECRET_NAME:-nem-web-e2e-credentials}
password=${E2E_PASSWORD:-}

if [[ -z "$keycloak_url" ]]; then
  keycloak_host=$(kubectl get service keycloak \
    --namespace "$keycloak_namespace" \
    --output jsonpath='{.spec.clusterIP}')
  keycloak_port=$(kubectl get service keycloak \
    --namespace "$keycloak_namespace" \
    --output jsonpath='{.spec.ports[0].port}')
  keycloak_url="http://$keycloak_host:$keycloak_port/auth"
fi

if [[ -z "$password" ]]; then
  password=$(openssl rand -base64 32 | tr -d '\n')
fi

admin_password=$(kubectl get secret nem-lume-secrets \
  --namespace "$namespace" \
  --output jsonpath='{.data.Keycloak__AdminPassword}' | base64 --decode)

admin_token=$(curl --fail --silent --show-error \
  --data-urlencode grant_type=password \
  --data-urlencode client_id=admin-cli \
  --data-urlencode username=admin \
  --data-urlencode password="$admin_password" \
  "$keycloak_url/realms/master/protocol/openid-connect/token" | jq --raw-output .access_token)
test -n "$admin_token"

admin_api="$keycloak_url/admin/realms/$realm"
user_id=$(curl --fail --silent --show-error \
  --get \
  --header "Authorization: Bearer $admin_token" \
  --data-urlencode "username=$username" \
  --data-urlencode exact=true \
  "$admin_api/users" | jq --raw-output '.[0].id // empty')

if [[ -z "$user_id" ]]; then
  create_body=$(jq --null-input --arg username "$username" \
    '{username: $username, enabled: true, emailVerified: true}')
  curl --fail --silent --show-error \
    --request POST \
    --header "Authorization: Bearer $admin_token" \
    --header 'Content-Type: application/json' \
    --data "$create_body" \
    "$admin_api/users"
  user_id=$(curl --fail --silent --show-error \
    --get \
    --header "Authorization: Bearer $admin_token" \
    --data-urlencode "username=$username" \
    --data-urlencode exact=true \
    "$admin_api/users" | jq --raw-output '.[0].id // empty')
fi

test -n "$user_id"
credential_body=$(jq --null-input --arg password "$password" \
  '{type: "password", value: $password, temporary: false}')
curl --fail --silent --show-error \
  --request PUT \
  --header "Authorization: Bearer $admin_token" \
  --header 'Content-Type: application/json' \
  --data "$credential_body" \
  "$admin_api/users/$user_id/reset-password"

roles='[]'
for role_name in FederationAdmin admin; do
  role=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$admin_api/roles/$role_name")
  roles=$(jq --argjson role "$role" '. + [$role]' <<<"$roles")
done
curl --fail --silent --show-error \
  --request POST \
  --header "Authorization: Bearer $admin_token" \
  --header 'Content-Type: application/json' \
  --data "$roles" \
  "$admin_api/users/$user_id/role-mappings/realm"

kubectl create secret generic "$secret_name" \
  --namespace "$namespace" \
  --from-literal=username="$username" \
  --from-literal=password="$password" \
  --dry-run=client \
  --output yaml \
  | kubectl apply --filename - >/dev/null

unset admin_password admin_token password credential_body roles role keycloak_host keycloak_port
printf 'Provisioned Keycloak user %s and Kubernetes secret %s/%s.\n' "$username" "$namespace" "$secret_name"
