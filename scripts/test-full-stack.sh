#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.classification.yml"
ENV_FILE=".env.classification"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

wait_for_healthy() {
  local service="$1"
  local attempts="${2:-60}"
  local sleep_seconds="${3:-5}"

  echo "Waiting for ${service} to become healthy..."
  for ((i = 1; i <= attempts; i++)); do
    local cid
    cid="$(docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps -q "${service}" 2>/dev/null || true)"

    if [[ -n "${cid}" ]]; then
      local status
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${cid}" 2>/dev/null || true)"
      if [[ "${status}" == "healthy" || "${status}" == "running" ]]; then
        echo "${service} is ${status}."
        return 0
      fi
    fi

    if [[ "${i}" -eq "${attempts}" ]]; then
      echo "Timed out waiting for ${service}" >&2
      return 1
    fi

    sleep "${sleep_seconds}"
  done
}

curl_retry() {
  local name="$1"
  local url="$2"

  echo "Checking ${name}: ${url}"
  curl --fail --silent --show-error --retry 20 --retry-delay 2 --retry-connrefused "${url}" >/dev/null
}

wait_for_healthy postgres
wait_for_healthy rabbitmq
wait_for_healthy opa

wait_for_healthy keycloak
wait_for_healthy presidio
wait_for_healthy classification
wait_for_healthy comms
wait_for_healthy openbao
wait_for_healthy mcp-api
wait_for_healthy mcp-ui
wait_for_healthy mimir
wait_for_healthy knowhub

curl_retry "rabbitmq management" "http://localhost:15672"
curl_retry "keycloak" "http://localhost:8080/health/ready"
curl_retry "opa" "http://localhost:8181/health"
curl_retry "presidio" "http://localhost:5001/health"
curl_retry "classification" "http://localhost:5270/health"
curl_retry "comms" "http://localhost:5280/health"
curl_retry "openbao" "http://localhost:8200/v1/sys/health"
curl_retry "mcp-api" "http://localhost:5000/health"
curl_retry "mcp-ui" "http://localhost:4200"
curl_retry "mimir" "http://localhost:5223/health"
curl_retry "knowhub" "http://localhost:5100/api/v1/health"

echo "✅ Full stack smoke test passed"
