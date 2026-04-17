#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/.local"
BOOTSTRAP_ENV="${LOCAL_DIR}/bootstrap.env"
RUNTIME_ENV="${LOCAL_DIR}/runtime.env"
REPORT_PATH="${LOCAL_DIR}/last-report.txt"

BASE_COMPOSE=(docker compose --env-file "$RUNTIME_ENV" -f docker-compose.yml -f docker-compose.local.yml)
KNOWHUB_COMPOSE=(docker compose --env-file "$RUNTIME_ENV" -f docker-compose.yml -f docker-compose.local.yml -f docker-compose.knowhub-empty-plugins.yml)

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

random_secret() {
  python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
}

docker_env_value() {
  local container="$1"
  local key="$2"

  if ! docker inspect "$container" >/dev/null 2>&1; then
    return 1
  fi

  docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
    | python3 -c "import sys; key = sys.argv[1];
for line in sys.stdin.read().splitlines():
    if line.startswith(f'{key}='):
        print(line.split('=', 1)[1])
        break" "$key"
}

ensure_network() {
  docker network inspect nem-network >/dev/null 2>&1 || docker network create nem-network >/dev/null
}

sync_postgres_password() {
  docker exec -u postgres nem-postgres \
    psql -v ON_ERROR_STOP=1 -d postgres \
    -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';" >/dev/null
}

ensure_local_files() {
  mkdir -p "$LOCAL_DIR"

  local postgres_password rabbitmq_user rabbitmq_pass keycloak_admin keycloak_admin_password
  local pgadmin_password grafana_password vault_token litellm_master_key

  postgres_password="$(docker_env_value nem-postgres POSTGRES_PASSWORD || true)"
  rabbitmq_user="$(docker_env_value nem-rabbitmq RABBITMQ_DEFAULT_USER || true)"
  rabbitmq_pass="$(docker_env_value nem-rabbitmq RABBITMQ_DEFAULT_PASS || true)"
  keycloak_admin="$(docker_env_value nem-keycloak KEYCLOAK_ADMIN || true)"
  keycloak_admin_password="$(docker_env_value nem-keycloak KEYCLOAK_ADMIN_PASSWORD || true)"
  pgadmin_password="$(docker_env_value nem-pgadmin PGADMIN_DEFAULT_PASSWORD || true)"
  grafana_password="$(docker_env_value nem-grafana GF_SECURITY_ADMIN_PASSWORD || true)"
  vault_token="$(docker_env_value nem-vault BAO_DEV_ROOT_TOKEN_ID || true)"
  litellm_master_key="$(docker_env_value nem-litellm-proxy LITELLM_MASTER_KEY || true)"

  cat > "$BOOTSTRAP_ENV" <<EOF
POSTGRES_PASSWORD=${postgres_password:-$(random_secret)}
RABBITMQ_DEFAULT_USER=${rabbitmq_user:-nem_local}
RABBITMQ_DEFAULT_PASS=${rabbitmq_pass:-$(random_secret)}
KEYCLOAK_ADMIN=${keycloak_admin:-admin}
KEYCLOAK_ADMIN_PASSWORD=${keycloak_admin_password:-$(random_secret)}
PGADMIN_DEFAULT_PASSWORD=${pgadmin_password:-$(random_secret)}
GF_SECURITY_ADMIN_PASSWORD=${grafana_password:-$(random_secret)}
BAO_DEV_ROOT_TOKEN_ID=${vault_token:-$(random_secret)}
LITELLM_MASTER_KEY=${litellm_master_key:-$(random_secret)}
NEM_MCP_INTERNAL_API_KEY=$(random_secret)
KNOWHUB_VECTOR_STORE_KEY=$(random_secret)
COMMS_SMTP_PASSWORD=$(random_secret)
COMMS_WEBHOOK_SECRET=$(random_secret)
KEYCLOAK_MCP_CLIENT_SECRET=$(random_secret)
KEYCLOAK_MIMIR_CLIENT_SECRET=$(random_secret)
EOF
  chmod 600 "$BOOTSTRAP_ENV"

  : > "$RUNTIME_ENV"
  chmod 600 "$RUNTIME_ENV"
}

load_bootstrap_env() {
  set -a
  source "$BOOTSTRAP_ENV"
  set +a
}

compose_bootstrap() {
  docker compose --env-file "$BOOTSTRAP_ENV" -f docker-compose.yml -f docker-compose.local.yml "$@"
}

vault_get() {
  local path="$1"
  local field="$2"
  docker exec \
    -e VAULT_ADDR="http://127.0.0.1:8200" \
    -e VAULT_TOKEN="$BAO_DEV_ROOT_TOKEN_ID" \
    nem-vault \
    bao kv get -mount=secret -field="$field" "$path"
}

render_runtime_env() {
  cat > "$RUNTIME_ENV" <<EOF
POSTGRES_PASSWORD=$(vault_get nem/infrastructure postgres_password)
RABBITMQ_DEFAULT_USER=$(vault_get nem/infrastructure rabbitmq_default_user)
RABBITMQ_DEFAULT_PASS=$(vault_get nem/infrastructure rabbitmq_default_pass)
KEYCLOAK_ADMIN=$(vault_get nem/infrastructure keycloak_admin)
KEYCLOAK_ADMIN_PASSWORD=$(vault_get nem/infrastructure keycloak_admin_password)
PGADMIN_DEFAULT_PASSWORD=$(vault_get nem/infrastructure pgadmin_default_password)
GF_SECURITY_ADMIN_PASSWORD=$(vault_get nem/infrastructure grafana_admin_password)
BAO_DEV_ROOT_TOKEN_ID=$BAO_DEV_ROOT_TOKEN_ID
LITELLM_MASTER_KEY=$(vault_get nem/infrastructure litellm_master_key)
EOF
  chmod 600 "$RUNTIME_ENV"
}

wait_for_service_state() {
  local service="$1"
  local desired="$2"
  local attempts="${3:-60}"
  local sleep_seconds="${4:-5}"
  local compose_mode="${5:-base}"
  local compose_ref_name="BASE_COMPOSE"

  if [[ "$compose_mode" == "knowhub" ]]; then
    compose_ref_name="KNOWHUB_COMPOSE"
  fi

  local -n compose_ref="$compose_ref_name"

  for ((i = 1; i <= attempts; i++)); do
    local cid
    cid="$("${compose_ref[@]}" ps -q "$service" 2>/dev/null || true)"

    if [[ -n "$cid" ]]; then
      local status
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
      if [[ "$status" == "$desired" ]]; then
        return 0
      fi
      if [[ "$desired" == "healthy" && "$status" == "running" ]]; then
        return 0
      fi
    fi

    sleep "$sleep_seconds"
  done

  return 1
}

report_service() {
  local service="$1"
  local compose_mode="${2:-base}"
  local compose_ref_name="BASE_COMPOSE"

  if [[ "$compose_mode" == "knowhub" ]]; then
    compose_ref_name="KNOWHUB_COMPOSE"
  fi

  local -n compose_ref="$compose_ref_name"

  {
    echo "===== ${service} status ====="
    "${compose_ref[@]}" ps -a "$service" || true
    echo
    echo "===== ${service} logs ====="
    docker logs --tail 120 "$("${compose_ref[@]}" ps -q "$service" 2>/dev/null || echo "$service")" 2>&1 || docker logs --tail 120 "$service" 2>&1 || true
    echo
  } >> "$REPORT_PATH"
}

ensure_ollama_model() {
  local model="$1"

  if python3 - "$model" "$(docker exec nem-ollama ollama list)" <<'PY'
import sys

model = sys.argv[1]
output = sys.argv[2]
lines = output.splitlines()[1:]
models = [line.split()[0] for line in lines if line.strip()]

def normalize(name: str) -> str:
    return name[:-7] if name.endswith(':latest') else name

normalized = {normalize(name) for name in models}
sys.exit(0 if model in normalized else 1)
PY
  then
    echo "Ollama model ${model} already present"
    return 0
  fi

  echo "Pulling Ollama embedding model ${model}"
  docker exec nem-ollama ollama pull "$model"
}

bootstrap_infra() {
  compose_bootstrap up -d postgres rabbitmq vault redis grafana otel-collector opa litellm-proxy ollama qdrant

  wait_for_service_state postgres healthy 60 5
  wait_for_service_state rabbitmq healthy 60 5
  wait_for_service_state vault running 60 3
  wait_for_service_state redis healthy 60 3
  wait_for_service_state ollama healthy 60 5
  wait_for_service_state litellm-proxy healthy 60 5
  wait_for_service_state qdrant healthy 60 5

  sync_postgres_password

  compose_bootstrap up -d keycloak pgadmin

  wait_for_service_state keycloak healthy 90 5
  wait_for_service_state pgadmin running 60 3
}

bootstrap_local_models() {
  ensure_ollama_model "nomic-embed-text"
}

seed_openbao() {
  VAULT_ADDR="http://127.0.0.1:8200" \
    VAULT_TOKEN="$BAO_DEV_ROOT_TOKEN_ID" \
    bash "$ROOT_DIR/openbao/init-dev.sh"
}

recover_apps() {
  "${BASE_COMPOSE[@]}" up -d --build --force-recreate nem-mcp nem-mimir nem-inferencegateway nem-scheduler nem-workflow
  "${KNOWHUB_COMPOSE[@]}" up -d --build --force-recreate nem-knowhub
}

verify_targets() {
  : > "$REPORT_PATH"

  local failures=0
  for service in nem-mcp nem-mimir nem-inferencegateway nem-scheduler nem-workflow; do
    if ! wait_for_service_state "$service" healthy 80 5; then
      failures=1
      report_service "$service"
    fi
  done

  if ! wait_for_service_state nem-knowhub healthy 60 5 knowhub; then
    failures=1
    report_service nem-knowhub knowhub
  fi

  if [[ $failures -ne 0 ]]; then
    echo "One or more services failed verification. See $REPORT_PATH" >&2
    return 1
  fi

  return 0
}

main() {
  require_command docker
  require_command python3
  cd "$ROOT_DIR"

  ensure_network
  ensure_local_files
  load_bootstrap_env
  bootstrap_infra
  bootstrap_local_models
  seed_openbao
  render_runtime_env
  recover_apps
  verify_targets

  echo "✅ nem local stack recovered and verified"
}

main "$@"
