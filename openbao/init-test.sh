#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:?VAULT_TOKEN must be set}"
export VAULT_ADDR VAULT_TOKEN

bao_cmd() {
  if command -v bao >/dev/null 2>&1; then
    bao "$@"
    return
  fi

  docker exec \
    -e VAULT_ADDR="$VAULT_ADDR" \
    -e VAULT_TOKEN="$VAULT_TOKEN" \
    nem-vault \
    bao "$@"
}

bao_policy_write() {
  local policy_name="$1"
  local policy_file="$2"

  if command -v bao >/dev/null 2>&1; then
    bao policy write "$policy_name" "$policy_file"
    return
  fi

  docker exec -i \
    -e VAULT_ADDR="$VAULT_ADDR" \
    -e VAULT_TOKEN="$VAULT_TOKEN" \
    nem-vault \
    sh -lc "cat > /tmp/${policy_name}.hcl && bao policy write '${policy_name}' /tmp/${policy_name}.hcl && rm /tmp/${policy_name}.hcl" \
    < "$policy_file"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

require_env POSTGRES_PASSWORD
require_env RABBITMQ_DEFAULT_USER
require_env RABBITMQ_DEFAULT_PASS
require_env KEYCLOAK_ADMIN
require_env KEYCLOAK_ADMIN_PASSWORD
require_env PGADMIN_DEFAULT_PASSWORD
require_env GF_SECURITY_ADMIN_PASSWORD
require_env LITELLM_MASTER_KEY
require_env NEM_MCP_INTERNAL_API_KEY
require_env KNOWHUB_VECTOR_STORE_KEY
require_env COMMS_SMTP_PASSWORD
require_env COMMS_WEBHOOK_SECRET
require_env KEYCLOAK_MCP_CLIENT_SECRET
require_env KEYCLOAK_MIMIR_CLIENT_SECRET

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="${SCRIPT_DIR}/policies"

echo "=== NEM OpenBao Test Init ==="
echo "VAULT_ADDR: ${VAULT_ADDR}"

bao_cmd secrets enable -path=secret kv-v2 || true
bao_cmd secrets enable transit || true
bao_cmd write -f transit/keys/nem-pii type=aes256-gcm96 || true

bao_cmd audit enable file file_path=/vault/logs/audit.log || true

for policy_file in "${POLICIES_DIR}"/*.hcl; do
  basename_no_ext="$(basename "$policy_file" .hcl)"
  policy_name="${basename_no_ext%-policy}"
  bao_policy_write "$policy_name" "$policy_file"
  echo "Loaded policy: $policy_name"
done

bao_cmd kv put secret/nem/infrastructure \
  postgres_password="$POSTGRES_PASSWORD" \
  rabbitmq_default_user="$RABBITMQ_DEFAULT_USER" \
  rabbitmq_default_pass="$RABBITMQ_DEFAULT_PASS" \
  keycloak_admin="$KEYCLOAK_ADMIN" \
  keycloak_admin_password="$KEYCLOAK_ADMIN_PASSWORD" \
  pgadmin_default_password="$PGADMIN_DEFAULT_PASSWORD" \
  grafana_admin_password="$GF_SECURITY_ADMIN_PASSWORD" \
  litellm_master_key="$LITELLM_MASTER_KEY"

bao_cmd kv put secret/nem/mcp \
  service_name="nem-mcp" \
  env="test" \
  db_connection_string="Host=postgres;Port=5432;Database=nemmcp;Username=postgres;Password=${POSTGRES_PASSWORD}" \
  api_key_internal="$NEM_MCP_INTERNAL_API_KEY"

bao_cmd kv put secret/nem/knowhub \
  service_name="nem-knowhub" \
  env="test" \
  db_connection_string="Host=postgres;Port=5432;Database=knowhub;Username=postgres;Password=${POSTGRES_PASSWORD}" \
  vector_store_key="$KNOWHUB_VECTOR_STORE_KEY"

bao_cmd kv put secret/nem/mimir \
  service_name="nem-mimir" \
  env="test" \
  db_connection_string="Host=postgres;Port=5432;Database=mimir;Username=postgres;Password=${POSTGRES_PASSWORD}"

bao_cmd kv put secret/nem/comms \
  service_name="nem-comms" \
  env="test" \
  smtp_password="$COMMS_SMTP_PASSWORD" \
  webhook_secret="$COMMS_WEBHOOK_SECRET"

bao_cmd kv put secret/nem/rabbitmq \
  username="$RABBITMQ_DEFAULT_USER" \
  password="$RABBITMQ_DEFAULT_PASS" \
  vhost="/"

bao_cmd kv put secret/nem/keycloak \
  admin_password="$KEYCLOAK_ADMIN_PASSWORD" \
  mcp_client_secret="$KEYCLOAK_MCP_CLIENT_SECRET" \
  mimir_client_secret="$KEYCLOAK_MIMIR_CLIENT_SECRET"

bao_cmd kv put secret/nem/inference \
  litellm_api_key="$LITELLM_MASTER_KEY" \
  lmstudio_api_url="http://localhost:1234/v1" \
  litellm_api_url="http://localhost:4000/v1"

bao_cmd auth enable approle || true

bao_cmd write auth/approle/role/nem-mcp-test \
  token_policies="nem-mcp" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao_cmd write auth/approle/role/nem-knowhub-test \
  token_policies="nem-knowhub" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao_cmd write auth/approle/role/nem-mimir-test \
  token_policies="nem-mimir" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao_cmd write auth/approle/role/nem-comms-test \
  token_policies="nem-comms" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao_cmd write auth/approle/role/nem-inference-test \
  token_policies="nem-inference" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

echo "=== Test init complete ==="
echo "AppRole role-ids:"
for svc in mcp knowhub mimir comms inference; do
  echo "  nem-${svc}: $(bao_cmd read -field=role_id "auth/approle/role/nem-${svc}-test/role-id")"
done
