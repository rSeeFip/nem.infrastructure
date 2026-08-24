#!/usr/bin/env bash
set -euo pipefail

namespace=${NAMESPACE:-nem-apps}
keycloak_namespace=${KEYCLOAK_NAMESPACE:-platform-identity}
keycloak_url=${KEYCLOAK_URL:-}
realm=${KEYCLOAK_REALM:-nem}
client_id=${KEYCLOAK_CLIENT_ID:-nem-web}
audience=${KEYCLOAK_AUDIENCE:-realm-management}
mapper_name=${KEYCLOAK_AUDIENCE_MAPPER_NAME:-audience-realm-management}
claim_name=${KEYCLOAK_CLAIM_NAME:-}
claim_value=${KEYCLOAK_CLAIM_VALUE:-}
claim_mapper_name=${KEYCLOAK_CLAIM_MAPPER_NAME:-hardcoded-service-claim}
realm_role=${KEYCLOAK_REALM_ROLE:-}

if [[ -n "$claim_name" && -z "$claim_value" ]] || [[ -z "$claim_name" && -n "$claim_value" ]]; then
  printf 'KEYCLOAK_CLAIM_NAME and KEYCLOAK_CLAIM_VALUE must be set together.\n' >&2
  exit 1
fi

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

if [[ -n "$claim_name" ]]; then
  claim_filter='[.[] | select(.protocolMapper == "oidc-hardcoded-claim-mapper" and .config["claim.name"] == $claim_name)]'
  claim_mappers=$(jq --arg claim_name "$claim_name" "$claim_filter" <<<"$verified_mappers")
  claim_mapper_count=$(jq 'length' <<<"$claim_mappers")
  if [[ "$claim_mapper_count" -gt 1 ]]; then
    printf 'Expected at most one %s claim mapper on %s, found %s.\n' \
      "$claim_name" "$client_id" "$claim_mapper_count" >&2
    exit 1
  fi

  claim_mapper_id=$(jq --raw-output 'if length == 1 then .[0].id else empty end' <<<"$claim_mappers")
  claim_mapper_body=$(jq --null-input \
    --arg id "$claim_mapper_id" \
    --arg name "$claim_mapper_name" \
    --arg claim_name "$claim_name" \
    --arg claim_value "$claim_value" \
    '{
      name: $name,
      protocol: "openid-connect",
      protocolMapper: "oidc-hardcoded-claim-mapper",
      consentRequired: false,
      config: {
        "claim.name": $claim_name,
        "claim.value": $claim_value,
        "jsonType.label": "String",
        "id.token.claim": "false",
        "access.token.claim": "true",
        "userinfo.token.claim": "false",
        "access.tokenResponse.claim": "false"
      }
    } + if $id == "" then {} else {id: $id} end')

  if [[ "$claim_mapper_count" -eq 0 ]]; then
    claim_response_code=$(printf '%s' "$claim_mapper_body" | curl --silent --show-error \
      --output /dev/null \
      --write-out '%{http_code}' \
      --request POST \
      --header "Authorization: Bearer $admin_token" \
      --header 'Content-Type: application/json' \
      --data-binary @- \
      "$mappers_url")
    if [[ "$claim_response_code" != 201 && "$claim_response_code" != 204 ]]; then
      printf 'Keycloak claim mapper creation failed with HTTP %s.\n' "$claim_response_code" >&2
      exit 1
    fi
  else
    claim_response_code=$(printf '%s' "$claim_mapper_body" | curl --silent --show-error \
      --output /dev/null \
      --write-out '%{http_code}' \
      --request PUT \
      --header "Authorization: Bearer $admin_token" \
      --header 'Content-Type: application/json' \
      --data-binary @- \
      "$mappers_url/$claim_mapper_id")
    if [[ "$claim_response_code" != 204 ]]; then
      printf 'Keycloak claim mapper update failed with HTTP %s.\n' "$claim_response_code" >&2
      exit 1
    fi
  fi

  verified_mappers=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$mappers_url")
  verified_claim_count=$(jq \
    --arg claim_name "$claim_name" \
    --arg claim_value "$claim_value" \
    '[.[] | select(
      .protocolMapper == "oidc-hardcoded-claim-mapper" and
      .config["claim.name"] == $claim_name and
      .config["claim.value"] == $claim_value and
      .config["access.token.claim"] == "true"
    )] | length' <<<"$verified_mappers")
  if [[ "$verified_claim_count" -ne 1 ]]; then
    printf 'Expected one verified %s claim mapper on %s, found %s.\n' \
      "$claim_name" "$client_id" "$verified_claim_count" >&2
    exit 1
  fi
fi

if [[ -n "$realm_role" ]]; then
  service_account_user=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$admin_api/clients/$client_uuid/service-account-user")
  service_account_user_id=$(jq --raw-output '.id' <<<"$service_account_user")
  test -n "$service_account_user_id"

  role_definition=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$admin_api/roles/$realm_role")
  role_mappings_url="$admin_api/users/$service_account_user_id/role-mappings/realm"
  client_scope_mappings_url="$admin_api/clients/$client_uuid/scope-mappings/realm"
  assigned_roles=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$role_mappings_url")
  assigned_role_count=$(jq --arg role "$realm_role" '[.[] | select(.name == $role)] | length' <<<"$assigned_roles")

  if [[ "$assigned_role_count" -gt 1 ]]; then
    printf 'Expected at most one %s realm role on %s, found %s.\n' \
      "$realm_role" "$client_id" "$assigned_role_count" >&2
    exit 1
  fi

  if [[ "$assigned_role_count" -eq 0 ]]; then
    role_response_code=$(jq --compact-output '[.]' <<<"$role_definition" | curl --silent --show-error \
      --output /dev/null \
      --write-out '%{http_code}' \
      --request POST \
      --header "Authorization: Bearer $admin_token" \
      --header 'Content-Type: application/json' \
      --data-binary @- \
      "$role_mappings_url")
    if [[ "$role_response_code" != 204 ]]; then
      printf 'Keycloak realm role assignment failed with HTTP %s.\n' "$role_response_code" >&2
      exit 1
    fi
  fi

  client_scope_roles=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$client_scope_mappings_url")
  client_scope_role_count=$(jq --arg role "$realm_role" '[.[] | select(.name == $role)] | length' <<<"$client_scope_roles")
  if [[ "$client_scope_role_count" -gt 1 ]]; then
    printf 'Expected at most one %s client scope role on %s, found %s.\n' \
      "$realm_role" "$client_id" "$client_scope_role_count" >&2
    exit 1
  fi

  if [[ "$client_scope_role_count" -eq 0 ]]; then
    client_scope_response_code=$(jq --compact-output '[.]' <<<"$role_definition" | curl --silent --show-error \
      --output /dev/null \
      --write-out '%{http_code}' \
      --request POST \
      --header "Authorization: Bearer $admin_token" \
      --header 'Content-Type: application/json' \
      --data-binary @- \
      "$client_scope_mappings_url")
    if [[ "$client_scope_response_code" != 204 ]]; then
      printf 'Keycloak client scope role assignment failed with HTTP %s.\n' "$client_scope_response_code" >&2
      exit 1
    fi
  fi

  verified_assigned_roles=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$role_mappings_url")
  verified_role_count=$(jq --arg role "$realm_role" '[.[] | select(.name == $role)] | length' <<<"$verified_assigned_roles")
  if [[ "$verified_role_count" -ne 1 ]]; then
    printf 'Expected one verified %s realm role on %s, found %s.\n' \
      "$realm_role" "$client_id" "$verified_role_count" >&2
    exit 1
  fi

  verified_client_scope_roles=$(curl --fail --silent --show-error \
    --header "Authorization: Bearer $admin_token" \
    "$client_scope_mappings_url")
  verified_client_scope_role_count=$(jq --arg role "$realm_role" '[.[] | select(.name == $role)] | length' <<<"$verified_client_scope_roles")
  if [[ "$verified_client_scope_role_count" -ne 1 ]]; then
    printf 'Expected one verified %s client scope role on %s, found %s.\n' \
      "$realm_role" "$client_id" "$verified_client_scope_role_count" >&2
    exit 1
  fi
fi

unset admin_password admin_token mapper_body clients mappers verified_mappers \
  client_uuid client_count mapper_count verified_count response_code keycloak_host keycloak_port \
  claim_mappers claim_mapper_count claim_mapper_id claim_mapper_body claim_response_code verified_claim_count \
  service_account_user service_account_user_id role_definition role_mappings_url assigned_roles \
  assigned_role_count role_response_code verified_assigned_roles verified_role_count client_scope_mappings_url \
  client_scope_roles client_scope_role_count client_scope_response_code verified_client_scope_roles \
  verified_client_scope_role_count
printf 'Reconciled Keycloak client %s audience %s.\n' "$client_id" "$audience"
