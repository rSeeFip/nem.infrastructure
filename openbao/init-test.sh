#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-test-root-token}"
export VAULT_ADDR VAULT_TOKEN

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="${SCRIPT_DIR}/policies"

echo "=== NEM OpenBao Test Init ==="
echo "VAULT_ADDR: ${VAULT_ADDR}"

bao secrets enable -path=secret kv-v2 || true
bao secrets enable transit || true
bao write -f transit/keys/nem-pii type=aes256-gcm96 || true

bao audit enable file file_path=/vault/logs/audit.log || true

for policy_file in "${POLICIES_DIR}"/*.hcl; do
  basename_no_ext="$(basename "$policy_file" .hcl)"
  policy_name="${basename_no_ext%-policy}"
  bao policy write "$policy_name" "$policy_file"
  echo "Loaded policy: $policy_name"
done

bao kv put secret/nem/mcp \
  service_name="nem-mcp" \
  env="test" \
  db_connection_string="Host=localhost;Database=nem_mcp_test;Username=nem_mcp;Password=test-mcp-db-pass-abc123" \
  api_key_internal="test-mcp-internal-key-xyz789"

bao kv put secret/nem/knowhub \
  service_name="nem-knowhub" \
  env="test" \
  db_connection_string="Host=localhost;Database=nem_knowhub_test;Username=nem_knowhub;Password=test-knowhub-db-pass-def456" \
  vector_store_key="test-vector-key-ghi012"

bao kv put secret/nem/mimir \
  service_name="nem-mimir" \
  env="test" \
  db_connection_string="Host=localhost;Database=nem_mimir_test;Username=nem_mimir;Password=test-mimir-db-pass-jkl345"

bao kv put secret/nem/comms \
  service_name="nem-comms" \
  env="test" \
  smtp_password="test-smtp-pass-mno678" \
  webhook_secret="test-webhook-secret-pqr901"

bao kv put secret/nem/rabbitmq \
  username="nem_test" \
  password="test-rabbitmq-pass-stu234" \
  vhost="nem_test"

bao kv put secret/nem/keycloak \
  admin_password="test-keycloak-admin-vwx567" \
  mcp_client_secret="test-mcp-client-secret-yza890" \
  mimir_client_secret="test-mimir-client-secret-bcd123"

bao kv put secret/nem/inference \
  litellm_api_key="test-litellm-key-efg456" \
  lmstudio_api_url="http://localhost:1234/v1" \
  litellm_api_url="http://localhost:4000/v1"

bao auth enable approle || true

bao write auth/approle/role/nem-mcp-test \
  token_policies="nem-mcp" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao write auth/approle/role/nem-knowhub-test \
  token_policies="nem-knowhub" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao write auth/approle/role/nem-mimir-test \
  token_policies="nem-mimir" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao write auth/approle/role/nem-comms-test \
  token_policies="nem-comms" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

bao write auth/approle/role/nem-inference-test \
  token_policies="nem-inference" \
  token_ttl=30m \
  token_max_ttl=2h \
  secret_id_ttl=0

echo "=== Test init complete ==="
echo "AppRole role-ids:"
for svc in mcp knowhub mimir comms inference; do
  echo "  nem-${svc}: $(bao read -field=role_id "auth/approle/role/nem-${svc}-test/role-id")"
done
