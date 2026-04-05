#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
export VAULT_ADDR VAULT_TOKEN

# Resolve policies directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="${SCRIPT_DIR}/policies"

echo "=== NEM OpenBao Dev Init ==="
echo "VAULT_ADDR: ${VAULT_ADDR}"

# Enable KV v2 secrets engine (idempotent)
bao secrets enable -path=secret kv-v2 || true

# Enable transit engine (idempotent)
bao secrets enable transit || true

# Create transit encryption key for PII (idempotent)
bao write -f transit/keys/nem-pii type=aes256-gcm96 || true

# Load all policies (strips -policy suffix from filename to get canonical policy name)
for policy_file in "${POLICIES_DIR}"/*.hcl; do
  basename_no_ext="$(basename "$policy_file" .hcl)"
  # Strip trailing -policy suffix if present: nem-mcp-policy -> nem-mcp
  policy_name="${basename_no_ext%-policy}"
  bao policy write "$policy_name" "$policy_file"
  echo "Loaded policy: $policy_name (from ${policy_file})"
done

# Write dev secrets
bao kv put secret/nem/mcp \
  service_name="nem-mcp" \
  env="dev" \
  db_connection_string="Host=localhost;Database=nem_mcp_dev;Username=nem_mcp;Password=dev-mcp-db-pass" \
  api_key_internal="dev-mcp-internal-key"

bao kv put secret/nem/knowhub \
  service_name="nem-knowhub" \
  env="dev" \
  db_connection_string="Host=localhost;Database=nem_knowhub_dev;Username=nem_knowhub;Password=dev-knowhub-db-pass" \
  vector_store_key="dev-vector-key"

bao kv put secret/nem/mimir \
  service_name="nem-mimir" \
  env="dev" \
  db_connection_string="Host=localhost;Database=nem_mimir_dev;Username=nem_mimir;Password=dev-mimir-db-pass"

bao kv put secret/nem/comms \
  service_name="nem-comms" \
  env="dev" \
  smtp_password="dev-smtp-pass" \
  webhook_secret="dev-webhook-secret"

bao kv put secret/nem/rabbitmq \
  username="nem_dev" \
  password="dev-rabbitmq-pass" \
  vhost="nem_dev"

bao kv put secret/nem/keycloak \
  admin_password="dev-keycloak-admin" \
  mcp_client_secret="dev-mcp-client-secret" \
  mimir_client_secret="dev-mimir-client-secret"

bao kv put secret/nem/inference \
  litellm_api_key="dev-litellm-key" \
  lmstudio_api_url="http://192.168.1.85:1234/v1" \
  litellm_api_url="http://192.168.8.75:4000/v1"

# Enable AppRole auth method (idempotent)
bao auth enable approle || true

# Create AppRole for nem-mcp
bao write auth/approle/role/nem-mcp-dev \
  token_policies="nem-mcp" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0

echo "=== Dev init complete ==="
echo "AppRole role-id: $(bao read -field=role_id auth/approle/role/nem-mcp-dev/role-id)"
