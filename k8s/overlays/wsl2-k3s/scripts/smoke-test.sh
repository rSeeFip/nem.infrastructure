#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="nem"
SSH_USER="${NEM_SMOKE_SSH_USER:-sendo}"
SSH_HOST="${NEM_SMOKE_SSH_HOST:-192.168.5.41}"
SSH_PORT="${NEM_SMOKE_SSH_PORT:-2222}"
EXEC_MODE="${NEM_SMOKE_MODE:-auto}"

VERBOSE=false
JSON_OUTPUT=false
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
RESULTS_JSON='[]'
EXEC_TARGET=""
RUNNER_CURL_READY=false

EXPECTED_APPS=(
  postgres
  rabbitmq
  keycloak
  openbao
  otel-collector
  prometheus
  loki
  tempo
  grafana
  pgadmin
  nem-mcp
  nem-knowhub
  nem-mimir
  nem-classification
  nem-comms
  nem-backup
  nem-scheduler
  nem-mediahub
  nem-web
  nem-homeassistant
  nem-gateway
  registry
  nem-configuration
)

HTTP_HEALTH_CHECKS=(
  "Keycloak|http://keycloak:8080/health/ready|200|FAIL|"
  "Grafana|http://grafana:3000/api/health|200|FAIL|"
  "Prometheus|http://prometheus:9090/-/healthy|200|FAIL|"
  "Loki|http://loki:3100/ready|200|FAIL|"
  "Tempo|http://tempo:3200/ready|200|FAIL|"
  "RabbitMQ|http://rabbitmq:15672/api/healthchecks/node|200|FAIL|-u guest:guest"
  "OpenBao|http://openbao:8200/v1/sys/health|200,429,472,473|FAIL|"
  "MCP API|http://nem-mcp:8080/health|200|FAIL|"
  "KnowHub|http://nem-knowhub:5001/health|200|FAIL|"
  "Mimir|http://nem-mimir:5223/health|200|FAIL|"
  "Classification|http://nem-classification:5300/health|200|FAIL|"
  "Comms|http://nem-comms:5400/health|200|FAIL|"
  "Backup|http://nem-backup:5500/health|200|FAIL|"
  "Scheduler|http://nem-scheduler:5600/health|200|FAIL|"
  "MediaHub|http://nem-mediahub:5700/health|200|FAIL|"
  "Web|http://nem-web:3000/|200,301,302,307,308|FAIL|"
  "HomeAssistant|http://nem-homeassistant:5800/health|200|FAIL|"
  "Gateway|http://nem-gateway:8090/health|200|FAIL|"
  "Configuration|http://nem-configuration:8080/health|200|FAIL|"
  "LiteLLM|http://litellm:4000/health|200|WARN|"
)

usage() {
  printf 'Usage: %s [--verbose] [--json]\n' "${0##*/}"
  printf '\n'
  printf 'Options:\n'
  printf '  --verbose   Include detailed per-check context\n'
  printf '  --json      Emit machine-readable JSON only\n'
  printf '  --help      Show this help\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  NEM_SMOKE_MODE           auto | local | ssh (default: auto)\n'
  printf '  NEM_SMOKE_SSH_USER       SSH user (default: sendo)\n'
  printf '  NEM_SMOKE_SSH_HOST       SSH host (default: 192.168.5.41)\n'
  printf '  NEM_SMOKE_SSH_PORT       SSH port (default: 2222)\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      ;;
    --json)
      JSON_OUTPUT=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$JSON_OUTPUT" == true ]] && ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required when using --json\n' >&2
  exit 2
fi

if [[ "$JSON_OUTPUT" == true || ! -t 1 || -n "${NO_COLOR:-}" ]]; then
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

note() {
  local message="$1"
  if [[ "$JSON_OUTPUT" == false && "$VERBOSE" == true ]]; then
    printf '    %s\n' "$message"
  fi
}

section() {
  local name="$1"
  if [[ "$JSON_OUTPUT" == false ]]; then
    printf '\n%s== %s ==%s\n' "$BOLD$BLUE" "$name" "$RESET"
  fi
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

append_json_result() {
  local section_name="$1"
  local name="$2"
  local status="$3"
  local message="$4"

  if [[ "$JSON_OUTPUT" == true ]]; then
    RESULTS_JSON="$(jq -cn \
      --argjson current "$RESULTS_JSON" \
      --arg section "$section_name" \
      --arg name "$name" \
      --arg status "$status" \
      --arg message "$message" \
      '$current + [{section: $section, name: $name, status: $status, message: $message}]')"
  fi
}

record_result() {
  local section_name="$1"
  local name="$2"
  local status="$3"
  local message="$4"

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
  esac

  append_json_result "$section_name" "$name" "$status" "$message"

  if [[ "$JSON_OUTPUT" == false ]]; then
    printf '%s %-24s %s\n' "$(status_label "$status")" "$name" "$message"
  fi
}

run_target() {
  local cmd="$1"

  if [[ "$EXEC_MODE" == "local" ]]; then
    bash -lc "$cmd"
  else
    ssh "${SSH_USER}@${SSH_HOST}" -p "$SSH_PORT" "$cmd"
  fi
}

resolve_exec_mode() {
  case "$EXEC_MODE" in
    local|ssh)
      ;;
    auto)
      if bash -lc "kubectl get namespace ${NAMESPACE} >/dev/null 2>&1"; then
        EXEC_MODE="local"
      else
        EXEC_MODE="ssh"
      fi
      ;;
    *)
      printf 'Invalid NEM_SMOKE_MODE: %s\n' "$EXEC_MODE" >&2
      exit 2
      ;;
  esac
}

count_nonempty_lines() {
  local text="${1-}"
  local count=0
  local line=""

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    count=$((count + 1))
  done <<< "$text"

  printf '%s\n' "$count"
}

code_allowed() {
  local code="$1"
  local allowed_csv="$2"
  local allowed_codes=()
  local allowed=""

  IFS=',' read -r -a allowed_codes <<< "$allowed_csv"
  for allowed in "${allowed_codes[@]}"; do
    if [[ "$code" == "$allowed" ]]; then
      return 0
    fi
  done

  return 1
}

resolve_exec_target() {
  local candidates=(
    "deploy/nem-mcp"
    "deploy/nem-mimir"
    "deploy/nem-configuration"
    "deploy/nem-web"
  )
  local candidate=""
  local running_pods_jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}'
  local running_pods=""
  local pod_name=""
  local fallback_target=""

  for candidate in "${candidates[@]}"; do
    if run_target "kubectl get -n ${NAMESPACE} ${candidate}" >/dev/null 2>&1; then
      if [[ -z "$fallback_target" ]]; then
        fallback_target="$candidate"
      fi

      if run_target "kubectl exec -n ${NAMESPACE} ${candidate} -- curl --version" >/dev/null 2>&1; then
        EXEC_TARGET="$candidate"
        RUNNER_CURL_READY=true
        return
      fi
    fi
  done

  if running_pods="$(run_target "kubectl get pods -n ${NAMESPACE} -o jsonpath='${running_pods_jsonpath}'" 2>/dev/null)"; then
    while IFS= read -r pod_name; do
      [[ -z "$pod_name" ]] && continue
      if [[ -z "$fallback_target" ]]; then
        fallback_target="pod/${pod_name}"
      fi

      if run_target "kubectl exec -n ${NAMESPACE} pod/${pod_name} -- curl --version" >/dev/null 2>&1; then
        EXEC_TARGET="pod/${pod_name}"
        RUNNER_CURL_READY=true
        return
      fi
    done <<< "$running_pods"
  fi

  if [[ -n "$fallback_target" ]]; then
    EXEC_TARGET="$fallback_target"
  fi

  if [[ -z "$EXEC_TARGET" ]]; then
    if running_pods="$(run_target "kubectl get pods -n ${NAMESPACE} -o jsonpath='${running_pods_jsonpath}'" 2>/dev/null)"; then
      while IFS= read -r pod_name; do
        [[ -z "$pod_name" ]] && continue
        EXEC_TARGET="pod/${pod_name}"
        break
      done <<< "$running_pods"
    fi
  fi

  RUNNER_CURL_READY=false
}

run_in_cluster_capture() {
  local command_text="$1"
  run_target "kubectl exec -n ${NAMESPACE} ${EXEC_TARGET} -- ${command_text}"
}

check_pod_health() {
  section "Pod Health"

  local jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.labels.app}{"|"}{.status.phase}{"|"}{range .status.containerStatuses[*]}{.ready}{","}{end}{"\n"}{end}'
  local pod_rows=""
  local row=""
  local pod_name=""
  local app_label=""
  local phase=""
  local ready_csv=""
  local ready_states=()
  local state=""
  local all_ready="true"
  local saw_container_status="false"
  local message=""
  local expected_app=""

  declare -A seen_expected_apps=()

  if ! pod_rows="$(run_target "kubectl get pods -n ${NAMESPACE} -o jsonpath='${jsonpath}'" 2>/dev/null)"; then
    record_result "Pod Health" "pods" "FAIL" "Unable to query pods in namespace ${NAMESPACE} via ${EXEC_MODE}"
    return
  fi

  if [[ -z "$pod_rows" ]]; then
    record_result "Pod Health" "pods" "FAIL" "No pods found in namespace ${NAMESPACE}"
    return
  fi

  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    IFS='|' read -r pod_name app_label phase ready_csv <<< "$row"

    if [[ -n "$app_label" ]]; then
      seen_expected_apps["$app_label"]=1
    fi

    if [[ "$phase" == "Succeeded" ]]; then
      record_result "Pod Health" "$pod_name" "WARN" "Completed pod detected (phase=${phase})"
      continue
    fi

    all_ready="true"
    saw_container_status="false"
    IFS=',' read -r -a ready_states <<< "$ready_csv"
    for state in "${ready_states[@]}"; do
      [[ -z "$state" ]] && continue
      saw_container_status="true"
      if [[ "$state" != "true" ]]; then
        all_ready="false"
      fi
    done

    if [[ "$saw_container_status" == "false" ]]; then
      all_ready="false"
    fi

    if [[ "$phase" == "Running" && "$all_ready" == "true" ]]; then
      message="phase=${phase}; ready=${ready_csv%,}"
      record_result "Pod Health" "$pod_name" "PASS" "$message"
    else
      message="phase=${phase}; ready=${ready_csv%,}"
      record_result "Pod Health" "$pod_name" "FAIL" "$message"
    fi
  done <<< "$pod_rows"

  for expected_app in "${EXPECTED_APPS[@]}"; do
    if [[ -z "${seen_expected_apps[$expected_app]+x}" ]]; then
      record_result "Pod Health" "app/${expected_app}" "FAIL" "No pod found with app=${expected_app}"
    fi
  done
}

check_service_endpoints() {
  section "Service Endpoints"

  local service_jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
  local endpoint_jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}'
  local services=""
  local service_name=""
  local addresses=""
  local endpoint_count=0
  local severity="FAIL"
  local message=""

  if ! services="$(run_target "kubectl get services -n ${NAMESPACE} -o jsonpath='${service_jsonpath}'" 2>/dev/null)"; then
    record_result "Service Endpoints" "services" "FAIL" "Unable to query services in namespace ${NAMESPACE} via ${EXEC_MODE}"
    return
  fi

  if [[ -z "$services" ]]; then
    record_result "Service Endpoints" "services" "FAIL" "No services found in namespace ${NAMESPACE}"
    return
  fi

  while IFS= read -r service_name; do
    [[ -z "$service_name" ]] && continue

    severity="FAIL"
    if [[ "$service_name" == "litellm" ]]; then
      severity="WARN"
    fi

    if addresses="$(run_target "kubectl get endpoints -n ${NAMESPACE} ${service_name} -o jsonpath='${endpoint_jsonpath}'" 2>/dev/null)"; then
      endpoint_count=$(count_nonempty_lines "$addresses")
      if [[ "$endpoint_count" -gt 0 ]]; then
        message="${endpoint_count} endpoint address(es)"
        if [[ "$VERBOSE" == true ]]; then
          message="${message}: ${addresses//$'\n'/, }"
          message="${message%, }"
        fi
        record_result "Service Endpoints" "$service_name" "PASS" "$message"
      else
        record_result "Service Endpoints" "$service_name" "$severity" "No ready endpoint addresses"
      fi
    else
      record_result "Service Endpoints" "$service_name" "$severity" "Unable to query endpoints"
    fi
  done <<< "$services"
}

check_http_health() {
  local name="$1"
  local url="$2"
  local allowed_codes="$3"
  local severity="$4"
  local extra_args="$5"
  local curl_command="curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5"
  local http_code=""
  local status="PASS"
  local message=""

  if [[ -z "$EXEC_TARGET" ]]; then
    record_result "Health Endpoints" "$name" "$severity" "No in-cluster exec target available for curl checks"
    return
  fi

  if [[ "$RUNNER_CURL_READY" != true ]]; then
    record_result "Health Endpoints" "$name" "$severity" "Exec target ${EXEC_TARGET} does not expose curl"
    return
  fi

  if [[ -n "$extra_args" ]]; then
    curl_command+=" ${extra_args}"
  fi
  curl_command+=" ${url}"

  if http_code="$(run_in_cluster_capture "$curl_command" 2>/dev/null)"; then
    if code_allowed "$http_code" "$allowed_codes"; then
      message="HTTP ${http_code}"
      if [[ "$VERBOSE" == true ]]; then
        message="${message} via ${EXEC_TARGET} -> ${url}"
      fi
      record_result "Health Endpoints" "$name" "PASS" "$message"
    else
      status="$severity"
      message="Unexpected HTTP ${http_code}"
      if [[ "$VERBOSE" == true ]]; then
        message="${message}; expected ${allowed_codes}; url=${url}; via=${EXEC_TARGET}"
      fi
      record_result "Health Endpoints" "$name" "$status" "$message"
    fi
  else
    status="$severity"
    message="Request failed"
    if [[ "$VERBOSE" == true ]]; then
      message="${message}; url=${url}; via=${EXEC_TARGET}"
    fi
    record_result "Health Endpoints" "$name" "$status" "$message"
  fi
}

check_postgres_health() {
  local output=""
  local message=""

  if output="$(run_target "kubectl exec -n ${NAMESPACE} deploy/postgres -- pg_isready -h postgres -p 5432 -U postgres" 2>/dev/null)"; then
    message="pg_isready succeeded"
    if [[ "$VERBOSE" == true && -n "$output" ]]; then
      message="$output"
    fi
    record_result "Health Endpoints" "PostgreSQL" "PASS" "$message"
  else
    record_result "Health Endpoints" "PostgreSQL" "FAIL" "pg_isready failed"
  fi
}

check_health_endpoints() {
  section "Health Endpoints"

  local check_spec=""
  local name=""
  local url=""
  local allowed_codes=""
  local severity=""
  local extra_args=""

  resolve_exec_target
  note "Execution mode: ${EXEC_MODE}"
  note "HTTP exec target: ${EXEC_TARGET:-unavailable}"

  check_postgres_health

  for check_spec in "${HTTP_HEALTH_CHECKS[@]}"; do
    IFS='|' read -r name url allowed_codes severity extra_args <<< "$check_spec"
    check_http_health "$name" "$url" "$allowed_codes" "$severity" "$extra_args"
  done
}

emit_summary() {
  section "Summary"

  if [[ "$JSON_OUTPUT" == true ]]; then
    jq -cn \
      --arg namespace "$NAMESPACE" \
      --arg mode "$EXEC_MODE" \
      --arg execTarget "$EXEC_TARGET" \
      --argjson pass "$PASS_COUNT" \
      --argjson fail "$FAIL_COUNT" \
      --argjson warn "$WARN_COUNT" \
      --argjson results "$RESULTS_JSON" \
      '{
        namespace: $namespace,
        mode: $mode,
        execTarget: (if $execTarget == "" then null else $execTarget end),
        summary: {
          pass: $pass,
          fail: $fail,
          warn: $warn
        },
        results: $results
      }'
  else
    printf '%sPASS=%s%s %sFAIL=%s%s %sWARN=%s%s\n' \
      "$GREEN$BOLD" "$PASS_COUNT" "$RESET" \
      "$RED$BOLD" "$FAIL_COUNT" "$RESET" \
      "$YELLOW$BOLD" "$WARN_COUNT" "$RESET"
    if [[ "$VERBOSE" == true ]]; then
      printf 'Mode: %s\n' "$EXEC_MODE"
      if [[ -n "$EXEC_TARGET" ]]; then
        printf 'HTTP exec target: %s\n' "$EXEC_TARGET"
      fi
    fi
  fi
}

main() {
  resolve_exec_mode
  check_pod_health
  check_service_endpoints
  check_health_endpoints
  emit_summary

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    exit 0
  fi

  exit 1
}

main
