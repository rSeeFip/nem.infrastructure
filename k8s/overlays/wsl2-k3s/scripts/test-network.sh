#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="nem"
DEFAULT_TARGET_HOST="192.168.5.41"
LITELLM_URL="http://192.168.8.75:4000/health"
WINDOWS_HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
WINDOWS_HOSTS_CHECK=false
TARGET_HOST_POSITIONAL_SET=false

TARGET_HOST="${NEM_NETWORK_TARGET_HOST:-$DEFAULT_TARGET_HOST}"

INGRESS_HOSTS=(
  keycloak.nem.local
  grafana.nem.local
  prometheus.nem.local
  mcp.nem.local
  mcp-ui.nem.local
  knowhub.nem.local
  mimir.nem.local
  classification.nem.local
  comms.nem.local
  backup.nem.local
  scheduler.nem.local
  mediahub.nem.local
  web.nem.local
  homeassistant.nem.local
  gateway.nem.local
  pgadmin.nem.local
  rabbitmq.nem.local
  openbao.nem.local
)

WINDOWS_TESTS=(
  "Keycloak|http://keycloak.nem.local/health/ready|200"
  "Grafana|http://grafana.nem.local/api/health|200"
)

LAN_TESTS=(
  "Grafana|grafana.nem.local|/api/health|200"
  "Keycloak|keycloak.nem.local|/health/ready|200"
  "Web|web.nem.local|/|200,301,302,307,308"
)

DNS_SERVICES=(
  keycloak
  rabbitmq
  postgres
  grafana
  prometheus
  nem-configuration
)

usage() {
  printf 'Usage: %s [TARGET_HOST] [--windows-hosts-check]\n' "${0##*/}"
  printf '\n'
  printf 'Verifies WSL2 mirrored-mode networking for the wsl2-k3s overlay.\n'
  printf '\n'
  printf 'Arguments:\n'
  printf '  TARGET_HOST              LAN IP / Windows host IP to test (default: %s)\n' "$DEFAULT_TARGET_HOST"
  printf '\n'
  printf 'Options:\n'
  printf '  --windows-hosts-check    Verify Windows hosts file contains *.nem.local entries\n'
  printf '  --help, -h               Show this help\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --windows-hosts-check)
      WINDOWS_HOSTS_CHECK=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ "$TARGET_HOST_POSITIONAL_SET" == true ]]; then
        printf 'Only one TARGET_HOST positional argument is allowed\n\n' >&2
        usage >&2
        exit 2
      fi
      TARGET_HOST="$1"
      TARGET_HOST_POSITIONAL_SET=true
      ;;
  esac
  shift
done

if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
  RESET=""
  BOLD=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
else
  RESET=$'\033[0m'
  BOLD=$'\033[1m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
fi

section() {
  local name="$1"
  printf '\n%s== %s ==%s\n' "$BOLD$BLUE" "$name" "$RESET"
}

status_label() {
  local status="$1"
  case "$status" in
    PASS) printf '%s[PASS]%s' "$GREEN$BOLD" "$RESET" ;;
    FAIL) printf '%s[FAIL]%s' "$RED$BOLD" "$RESET" ;;
    WARN) printf '%s[WARN]%s' "$YELLOW$BOLD" "$RESET" ;;
    *) printf '[%s]' "$status" ;;
  esac
}

record_result() {
  local name="$1"
  local status="$2"
  local message="$3"

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
  esac

  printf '%s %-32s %s\n' "$(status_label "$status")" "$name" "$message"
}

code_allowed() {
  local actual="$1"
  local allowed_csv="$2"
  local allowed_codes=()
  local allowed_code=""

  IFS=',' read -r -a allowed_codes <<< "$allowed_csv"
  for allowed_code in "${allowed_codes[@]}"; do
    if [[ "$actual" == "$allowed_code" ]]; then
      return 0
    fi
  done

  return 1
}

http_status() {
  local url="$1"
  shift
  curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 10 "$@" "$url"
}

run_local_ingress_checks() {
  section 'Test 1: IngressRoutes via localhost (WSL2)'

  local host=""
  local status_code=""
  local url=""

  for host in "${INGRESS_HOSTS[@]}"; do
    url="http://${host}/"
    if status_code="$(http_status "$url" --resolve "${host}:80:127.0.0.1" 2>/dev/null)"; then
      if code_allowed "$status_code" '200,301,302,307,308'; then
        record_result "$host" 'PASS' "HTTP ${status_code} via 127.0.0.1"
      else
        record_result "$host" 'FAIL' "Unexpected HTTP ${status_code} via 127.0.0.1"
      fi
    else
      record_result "$host" 'FAIL' 'Request failed via 127.0.0.1'
    fi
  done
}

check_windows_hosts_file() {
  local host=""

  if [[ ! -f "$WINDOWS_HOSTS_FILE" ]]; then
    record_result 'windows-hosts-file' 'WARN' "Not found at ${WINDOWS_HOSTS_FILE}"
    return
  fi

  for host in "${INGRESS_HOSTS[@]}"; do
    if grep -Eiv '^[[:space:]]*#' "$WINDOWS_HOSTS_FILE" | grep -Fqi "$host"; then
      record_result "hosts:${host}" 'PASS' 'Present in Windows hosts file'
    else
      record_result "hosts:${host}" 'FAIL' 'Missing from Windows hosts file'
    fi
  done
}

powershell_http_status() {
  local url="$1"

  powershell.exe -NoProfile -Command "\$ProgressPreference='SilentlyContinue'; try { \$response = Invoke-WebRequest -Uri '${url}' -TimeoutSec 10; [int]\$response.StatusCode } catch { if (\$_.Exception.Response) { [int]\$_.Exception.Response.StatusCode.value__ } else { exit 1 } }" 2>/dev/null | tr -d '\r\n'
}

run_windows_accessibility_checks() {
  section 'Test 2: Windows host accessibility'

  local test_spec=""
  local name=""
  local url=""
  local expected_codes=""
  local status_code=""

  if [[ "$WINDOWS_HOSTS_CHECK" == true ]]; then
    check_windows_hosts_file
  fi

  if ! command -v powershell.exe >/dev/null 2>&1; then
    record_result 'powershell.exe' 'WARN' 'Unavailable; skipping Windows-side checks (not WSL2?)'
    return
  fi

  for test_spec in "${WINDOWS_TESTS[@]}"; do
    IFS='|' read -r name url expected_codes <<< "$test_spec"

    if status_code="$(powershell_http_status "$url")" && [[ -n "$status_code" ]]; then
      if code_allowed "$status_code" "$expected_codes"; then
        record_result "$name" 'PASS' "HTTP ${status_code} from Windows host"
      else
        record_result "$name" 'FAIL' "Unexpected HTTP ${status_code} from Windows host"
      fi
    else
      record_result "$name" 'FAIL' 'Request failed from Windows host (hosts file may be missing)'
    fi
  done
}

run_lan_accessibility_checks() {
  section 'Test 3: LAN accessibility'

  local test_spec=""
  local name=""
  local host=""
  local path=""
  local expected_codes=""
  local status_code=""

  for test_spec in "${LAN_TESTS[@]}"; do
    IFS='|' read -r name host path expected_codes <<< "$test_spec"

    if status_code="$(http_status "http://${TARGET_HOST}:80${path}" -H "Host: ${host}" 2>/dev/null)"; then
      if code_allowed "$status_code" "$expected_codes"; then
        record_result "$name" 'PASS' "HTTP ${status_code} via ${TARGET_HOST} with Host=${host}"
      else
        record_result "$name" 'FAIL' "Unexpected HTTP ${status_code} via ${TARGET_HOST} with Host=${host}"
      fi
    else
      record_result "$name" 'FAIL' "Request failed via ${TARGET_HOST} with Host=${host}"
    fi
  done
}

nslookup_succeeded() {
  local output="$1"

  if printf '%s\n' "$output" | grep -Eqi "NXDOMAIN|SERVFAIL|can't resolve|server can't find|timed out|no servers could be reached"; then
    return 1
  fi

  if printf '%s\n' "$output" | grep -Eq '^Name:' && printf '%s\n' "$output" | grep -Eq '^Address([[:space:]]+[0-9]+)?:'; then
    return 0
  fi

  return 1
}

run_internal_dns_checks() {
  section 'Test 4: Internal DNS resolution'

  local service=""
  local output=""

  if ! command -v kubectl >/dev/null 2>&1; then
    record_result 'kubectl' 'FAIL' 'kubectl is required for in-cluster DNS checks'
    return
  fi

  if ! kubectl get -n "$NAMESPACE" deploy/nem-mcp >/dev/null 2>&1; then
    record_result 'deploy/nem-mcp' 'FAIL' 'Deployment not found for nslookup checks'
    return
  fi

  for service in "${DNS_SERVICES[@]}"; do
    if output="$(kubectl exec -n "$NAMESPACE" deploy/nem-mcp -- nslookup "$service" 2>&1)"; then
      if nslookup_succeeded "$output"; then
        record_result "$service" 'PASS' 'Resolved inside namespace nem'
      else
        record_result "$service" 'FAIL' 'nslookup output did not contain a resolved IP'
      fi
    else
      record_result "$service" 'FAIL' 'nslookup command failed in deploy/nem-mcp'
    fi
  done
}

run_litellm_connectivity_check() {
  section 'Test 5: LiteLLM external connectivity'

  if ! command -v kubectl >/dev/null 2>&1; then
    record_result 'LiteLLM' 'WARN' 'kubectl is unavailable; skipping external connectivity check'
    return
  fi

  if ! kubectl get -n "$NAMESPACE" deploy/nem-mimir >/dev/null 2>&1; then
    record_result 'deploy/nem-mimir' 'WARN' 'Deployment not found for LiteLLM connectivity check'
    return
  fi

  if kubectl exec -n "$NAMESPACE" deploy/nem-mimir -- curl -sf --connect-timeout 10 "$LITELLM_URL" >/dev/null 2>&1; then
    record_result 'LiteLLM' 'PASS' "Reachable from deploy/nem-mimir (${LITELLM_URL})"
  else
    record_result 'LiteLLM' 'WARN' "Unreachable from deploy/nem-mimir (${LITELLM_URL})"
  fi
}

emit_summary() {
  section 'Summary'
  printf '%sPASS=%s%s %sFAIL=%s%s %sWARN=%s%s\n' \
    "$GREEN$BOLD" "$PASS_COUNT" "$RESET" \
    "$RED$BOLD" "$FAIL_COUNT" "$RESET" \
    "$YELLOW$BOLD" "$WARN_COUNT" "$RESET"
  printf 'TARGET_HOST=%s\n' "$TARGET_HOST"
  printf 'WSL2 mirrored networking expectation: Windows forwards port 80 to Traefik in WSL2/K3s.\n'
}

main() {
  run_local_ingress_checks
  run_windows_accessibility_checks
  run_lan_accessibility_checks
  run_internal_dns_checks
  run_litellm_connectivity_check
  emit_summary

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    exit 0
  fi

  exit 1
}

main
