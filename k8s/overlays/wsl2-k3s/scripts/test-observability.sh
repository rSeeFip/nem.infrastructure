#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="nem"
SSH_USER="${NEM_OBS_SSH_USER:-sendo}"
SSH_HOST="${NEM_OBS_SSH_HOST:-192.168.5.41}"
SSH_PORT="${NEM_OBS_SSH_PORT:-2222}"
EXEC_MODE="${NEM_OBS_MODE:-auto}"
VERBOSE=false

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

EXPECTED_DATASOURCES=(
  "Prometheus|prometheus|http://prometheus:9090|http://prometheus:9090/-/healthy"
  "Loki|loki|http://loki:3100|http://loki:3100/ready"
  "Tempo|tempo|http://tempo:3200|http://tempo:3200/ready"
)

EXPECTED_DASHBOARDS=(
  "log-explorer"
  "red-metrics"
  "trace-explorer"
  "infrastructure-overview"
)

usage() {
  printf 'Usage: %s [--verbose]\n' "${0##*/}"
  printf '\n'
  printf 'Options:\n'
  printf '  --verbose   Include extra execution details\n'
  printf '  --help      Show this help\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  NEM_OBS_MODE           auto | local | ssh (default: auto)\n'
  printf '  NEM_OBS_SSH_USER       SSH user (default: sendo)\n'
  printf '  NEM_OBS_SSH_HOST       SSH host (default: 192.168.5.41)\n'
  printf '  NEM_OBS_SSH_PORT       SSH port (default: 2222)\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
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

note() {
  local message="$1"
  if [[ "$VERBOSE" == true ]]; then
    printf '    %s\n' "$message"
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

record_result() {
  local name="$1"
  local status="$2"
  local message="$3"
  local elapsed_ns="$4"

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
  esac

  printf '%s %-38s %s (%s)\n' \
    "$(status_label "$status")" \
    "$name" \
    "$message" \
    "$(format_duration "$elapsed_ns")"
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$name" >&2
    exit 2
  fi
}

require_runtime_dependencies() {
  require_command python3

  if [[ "$EXEC_MODE" == "local" ]]; then
    require_command kubectl
  else
    require_command ssh
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
      printf 'Invalid NEM_OBS_MODE: %s\n' "$EXEC_MODE" >&2
      exit 2
      ;;
  esac
}

run_target() {
  local cmd="$1"

  if [[ "$EXEC_MODE" == "local" ]]; then
    bash -lc "$cmd"
  else
    ssh "${SSH_USER}@${SSH_HOST}" -p "$SSH_PORT" "$cmd"
  fi
}

now_ns() {
  date +%s%N
}

format_duration() {
  local elapsed_ns="$1"
  local elapsed_ms=$((elapsed_ns / 1000000))

  if (( elapsed_ms >= 1000 )); then
    printf '%d.%03ds' "$((elapsed_ms / 1000))" "$((elapsed_ms % 1000))"
  else
    printf '%dms' "$elapsed_ms"
  fi
}

build_kubectl_curl_command() {
  local workload="$1"
  shift

  local remote_cmd=""
  local quoted_arg=""
  printf -v remote_cmd 'kubectl exec -n %q %q -- curl' "$NAMESPACE" "$workload"

  for quoted_arg in "$@"; do
    local escaped=""
    printf -v escaped '%q' "$quoted_arg"
    remote_cmd+=" ${escaped}"
  done

  printf '%s\n' "$remote_cmd"
}

kubectl_curl() {
  local workload="$1"
  shift

  local remote_cmd=""
  remote_cmd="$(build_kubectl_curl_command "$workload" "$@")"
  run_target "$remote_cmd"
}

kubectl_http_code() {
  local workload="$1"
  local url="$2"
  kubectl_curl "$workload" -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "$url"
}

check_prometheus_targets() {
  local name="Test 1: Prometheus targets"
  local start_ns="$(now_ns)"
  local response=""
  local analysis=""
  local status=""
  local message=""
  local elapsed_ns=0

  if ! response="$(kubectl_curl "deploy/prometheus" -sf --connect-timeout 5 --max-time 15 "http://localhost:9090/api/v1/targets" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to query Prometheus targets API" "$elapsed_ns"
    return
  fi

  if ! analysis="$(OBS_RESPONSE="$response" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone

try:
    payload = json.loads(os.environ["OBS_RESPONSE"])
    targets = payload.get("data", {}).get("activeTargets", []) or []
    now = datetime.now(timezone.utc)
    up_count = 0
    fresh_count = 0

    for target in targets:
        if str(target.get("health", "")).lower() != "up":
            continue

        up_count += 1
        last_scrape = target.get("lastScrape")
        if not last_scrape:
            continue

        try:
            scraped_at = datetime.fromisoformat(last_scrape.replace("Z", "+00:00"))
        except ValueError:
            continue

        age_seconds = (now - scraped_at).total_seconds()
        if age_seconds < 60:
            fresh_count += 1

    if up_count < 5:
        print(f"FAIL\t{up_count} targets are UP; expected at least 5")
    elif fresh_count < 5:
        print(f"FAIL\t{up_count} targets are UP but only {fresh_count} scraped within 60s")
    else:
        print(f"PASS\t{up_count} targets are UP; {fresh_count} scraped within 60s")
except Exception as exc:
    print(f"FAIL\tUnable to parse Prometheus targets response: {exc}")
PY
)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to parse Prometheus targets response" "$elapsed_ns"
    return
  fi

  IFS=$'\t' read -r status message <<< "$analysis"
  elapsed_ns=$(( $(now_ns) - start_ns ))
  record_result "$name" "$status" "$message" "$elapsed_ns"
}

check_prometheus_metrics() {
  local name="Test 2: Prometheus nem metrics"
  local start_ns="$(now_ns)"
  local response=""
  local analysis=""
  local status=""
  local message=""
  local elapsed_ns=0
  local query_url="http://localhost:9090/api/v1/query?query=up{namespace=\"nem\"}"

  if ! response="$(kubectl_curl "deploy/prometheus" -g -sf --connect-timeout 5 --max-time 15 "$query_url" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to query Prometheus metrics API" "$elapsed_ns"
    return
  fi

  if ! analysis="$(OBS_RESPONSE="$response" python3 - <<'PY'
import json
import os
import time

try:
    payload = json.loads(os.environ["OBS_RESPONSE"])
    results = payload.get("data", {}).get("result", []) or []
    if not results:
        print("FAIL\tNo namespace=nem metric samples returned")
    else:
        newest_age = None
        fresh_count = 0

        for item in results:
            value = item.get("value") or []
            if len(value) < 2:
                continue

            timestamp = float(value[0])
            age_seconds = max(0.0, time.time() - timestamp)
            if newest_age is None or age_seconds < newest_age:
                newest_age = age_seconds
            if age_seconds <= 300:
                fresh_count += 1

        if newest_age is None:
            print("FAIL\tMetric samples did not include datapoint timestamps")
        elif fresh_count == 0:
            print(f"FAIL\t{len(results)} metric series returned but newest datapoint is {newest_age:.1f}s old")
        else:
            print(f"PASS\t{len(results)} metric series returned; newest datapoint age {newest_age:.1f}s; fresh series {fresh_count}")
except Exception as exc:
    print(f"FAIL\tUnable to parse Prometheus metrics response: {exc}")
PY
)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to parse Prometheus metrics response" "$elapsed_ns"
    return
  fi

  IFS=$'\t' read -r status message <<< "$analysis"
  elapsed_ns=$(( $(now_ns) - start_ns ))
  record_result "$name" "$status" "$message" "$elapsed_ns"
}

check_loki_logs() {
  local name="Test 3: Loki logs"
  local start_ns="$(now_ns)"
  local response=""
  local analysis=""
  local status=""
  local message=""
  local elapsed_ns=0
  local query_url="http://localhost:3100/loki/api/v1/query?query={namespace=\"nem\"}&limit=5"

  if ! response="$(kubectl_curl "deploy/loki" -g -sf --connect-timeout 5 --max-time 15 "$query_url" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to query Loki logs API" "$elapsed_ns"
    return
  fi

  if ! analysis="$(OBS_RESPONSE="$response" python3 - <<'PY'
import json
import os
import time

try:
    payload = json.loads(os.environ["OBS_RESPONSE"])
    streams = payload.get("data", {}).get("result", []) or []
    stream_count = 0
    entry_count = 0
    newest_age = None

    for stream in streams:
        labels = stream.get("stream", {}) or {}
        if labels.get("namespace") != "nem":
            continue

        values = stream.get("values", []) or []
        if not values:
            continue

        stream_count += 1
        entry_count += len(values)

        for value in values:
            if len(value) < 2:
                continue
            timestamp_ns = int(value[0])
            age_seconds = max(0.0, time.time() - (timestamp_ns / 1_000_000_000))
            if newest_age is None or age_seconds < newest_age:
                newest_age = age_seconds

    if entry_count == 0:
        print("FAIL\tNo Loki log entries found for namespace=nem")
    elif newest_age is None:
        print(f"FAIL\t{entry_count} Loki log entries found but timestamps were unreadable")
    elif newest_age > 300:
        print(f"FAIL\t{entry_count} Loki log entries found across {stream_count} stream(s), but newest entry is {newest_age:.1f}s old")
    else:
        print(f"PASS\t{entry_count} Loki log entries found across {stream_count} stream(s); newest entry age {newest_age:.1f}s")
except Exception as exc:
    print(f"FAIL\tUnable to parse Loki logs response: {exc}")
PY
)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to parse Loki logs response" "$elapsed_ns"
    return
  fi

  IFS=$'\t' read -r status message <<< "$analysis"
  elapsed_ns=$(( $(now_ns) - start_ns ))
  record_result "$name" "$status" "$message" "$elapsed_ns"
}

check_tempo_traces() {
  local name="Test 4: Tempo traces"
  local start_ns="$(now_ns)"
  local response=""
  local analysis=""
  local status=""
  local message=""
  local elapsed_ns=0
  local query_url="http://localhost:3200/api/search?limit=5"

  if ! response="$(kubectl_curl "deploy/tempo" -sf --connect-timeout 5 --max-time 15 "$query_url" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to query Tempo search API" "$elapsed_ns"
    return
  fi

  if ! analysis="$(OBS_RESPONSE="$response" python3 - <<'PY'
import json
import os
import time
from datetime import datetime, timezone

def coerce_epoch_seconds(value):
    if value in (None, ""):
        return None

    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        if stripped.isdigit():
            value = int(stripped)
        else:
            try:
                return datetime.fromisoformat(stripped.replace("Z", "+00:00")).timestamp()
            except ValueError:
                return None

    if isinstance(value, (int, float)):
        numeric = float(value)
        if numeric > 1e18:
            return numeric / 1_000_000_000
        if numeric > 1e15:
            return numeric / 1_000_000
        if numeric > 1e12:
            return numeric / 1000
        return numeric

    return None

try:
    payload = json.loads(os.environ["OBS_RESPONSE"])
    traces = payload.get("traces")
    if traces is None:
        traces = payload.get("data")
    if traces is None:
        traces = payload.get("results")
    if isinstance(traces, dict):
        traces = traces.get("traces") or traces.get("items") or []
    if traces is None:
        traces = []

    if not isinstance(traces, list) or len(traces) == 0:
        print("WARN\tNo Tempo traces found yet")
    else:
        newest_age = None
        for trace in traces:
            trace_timestamp = None
            for key in (
                "startTimeUnixNano",
                "startTimeUnixNs",
                "startTimeUnixMs",
                "startTimeUnix",
                "startTime",
                "traceStartTime",
                "rootStartTimeUnixNano",
            ):
                trace_timestamp = coerce_epoch_seconds(trace.get(key))
                if trace_timestamp is not None:
                    break

            if trace_timestamp is None:
                continue

            age_seconds = max(0.0, time.time() - trace_timestamp)
            if newest_age is None or age_seconds < newest_age:
                newest_age = age_seconds

        if newest_age is None:
            print(f"PASS\t{len(traces)} Tempo trace(s) found")
        elif newest_age > 300:
            print(f"WARN\t{len(traces)} Tempo trace(s) found, but newest trace is {newest_age:.1f}s old")
        else:
            print(f"PASS\t{len(traces)} Tempo trace(s) found; newest trace age {newest_age:.1f}s")
except Exception as exc:
    print(f"FAIL\tUnable to parse Tempo traces response: {exc}")
PY
)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to parse Tempo traces response" "$elapsed_ns"
    return
  fi

  IFS=$'\t' read -r status message <<< "$analysis"
  elapsed_ns=$(( $(now_ns) - start_ns ))
  record_result "$name" "$status" "$message" "$elapsed_ns"
}

check_grafana_datasources() {
  local name="Test 5: Grafana datasources"
  local start_ns="$(now_ns)"
  local response=""
  local analysis=""
  local status=""
  local message=""
  local elapsed_ns=0
  local spec=""
  local ds_name=""
  local ds_type=""
  local health_url=""
  local http_code=""
  local unreachable=()

  if ! response="$(kubectl_curl "deploy/grafana" -sf --connect-timeout 5 --max-time 15 -u admin:admin "http://localhost:3000/api/datasources" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to query Grafana datasources API" "$elapsed_ns"
    return
  fi

  if ! analysis="$(OBS_RESPONSE="$response" python3 - <<'PY'
import json
import os

expected = {
    "Prometheus": {"type": "prometheus", "url": "http://prometheus:9090"},
    "Loki": {"type": "loki", "url": "http://loki:3100"},
    "Tempo": {"type": "tempo", "url": "http://tempo:3200"},
}

try:
    payload = json.loads(os.environ["OBS_RESPONSE"])
    if not isinstance(payload, list):
        print("FAIL\tGrafana datasources API did not return a datasource list")
    else:
        by_name = {item.get("name"): item for item in payload if isinstance(item, dict)}
        missing = []
        mismatched = []

        for name, requirement in expected.items():
            current = by_name.get(name)
            if current is None:
                missing.append(name)
                continue

            current_type = current.get("type")
            current_url = current.get("url")
            if current_type != requirement["type"] or current_url != requirement["url"]:
                mismatched.append(
                    f"{name}(type={current_type or 'n/a'}, url={current_url or 'n/a'})"
                )

        if missing:
            print(f"FAIL\tMissing Grafana datasources: {', '.join(missing)}")
        elif mismatched:
            print(f"FAIL\tGrafana datasource config mismatch: {', '.join(mismatched)}")
        else:
            print("PASS\tPrometheus, Loki, and Tempo datasources are configured")
except Exception as exc:
    print(f"FAIL\tUnable to parse Grafana datasources response: {exc}")
PY
)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to parse Grafana datasources response" "$elapsed_ns"
    return
  fi

  IFS=$'\t' read -r status message <<< "$analysis"
  if [[ "$status" != "PASS" ]]; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "$status" "$message" "$elapsed_ns"
    return
  fi

  for spec in "${EXPECTED_DATASOURCES[@]}"; do
    IFS='|' read -r ds_name ds_type _ health_url <<< "$spec"
    if ! http_code="$(kubectl_http_code "deploy/grafana" "$health_url" 2>/dev/null)"; then
      unreachable+=("${ds_name}=request-failed")
      continue
    fi

    if [[ "$http_code" != "200" ]]; then
      unreachable+=("${ds_name}=HTTP ${http_code}")
    fi
  done

  elapsed_ns=$(( $(now_ns) - start_ns ))
  if [[ ${#unreachable[@]} -gt 0 ]]; then
    record_result "$name" "FAIL" "Datasource backends not reachable from Grafana: ${unreachable[*]}" "$elapsed_ns"
  else
    record_result "$name" "PASS" "Prometheus, Loki, and Tempo datasources are configured and reachable" "$elapsed_ns"
  fi
}

check_grafana_dashboards() {
  local name="Test 6: Grafana dashboards"
  local start_ns="$(now_ns)"
  local response=""
  local analysis=""
  local status=""
  local message=""
  local elapsed_ns=0

  if ! response="$(kubectl_curl "deploy/grafana" -sf --connect-timeout 5 --max-time 15 -u admin:admin "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to query Grafana dashboard search API" "$elapsed_ns"
    return
  fi

  if ! analysis="$(OBS_RESPONSE="$response" python3 - <<'PY'
import json
import os

required = {
    "log-explorer",
    "red-metrics",
    "trace-explorer",
    "infrastructure-overview",
}

try:
    payload = json.loads(os.environ["OBS_RESPONSE"])
    if not isinstance(payload, list):
        print("FAIL\tGrafana dashboard search API did not return a dashboard list")
    else:
        present = set()
        for item in payload:
            if not isinstance(item, dict):
                continue
            for candidate in (item.get("uid"), item.get("uri"), item.get("title")):
                if candidate:
                    present.add(str(candidate))

        missing = [dashboard for dashboard in sorted(required) if dashboard not in present]
        if missing:
            print(f"FAIL\tMissing Grafana dashboards: {', '.join(missing)}")
        else:
            print("PASS\tRequired Grafana dashboards are loaded")
except Exception as exc:
    print(f"FAIL\tUnable to parse Grafana dashboards response: {exc}")
PY
)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "Unable to parse Grafana dashboards response" "$elapsed_ns"
    return
  fi

  IFS=$'\t' read -r status message <<< "$analysis"
  elapsed_ns=$(( $(now_ns) - start_ns ))
  record_result "$name" "$status" "$message" "$elapsed_ns"
}

check_otel_collector() {
  local name="Test 7: OTel Collector"
  local start_ns="$(now_ns)"
  local response=""
  local elapsed_ns=0

  if ! response="$(kubectl_curl "deploy/otel-collector" -sf --connect-timeout 5 --max-time 15 "http://localhost:13133/" 2>/dev/null)"; then
    elapsed_ns=$(( $(now_ns) - start_ns ))
    record_result "$name" "FAIL" "OTel Collector health endpoint did not pass" "$elapsed_ns"
    return
  fi

  response="${response//$'\n'/ }"
  elapsed_ns=$(( $(now_ns) - start_ns ))
  if [[ -n "$response" ]]; then
    record_result "$name" "PASS" "Collector health check passed: ${response}" "$elapsed_ns"
  else
    record_result "$name" "PASS" "Collector health check passed" "$elapsed_ns"
  fi
}

emit_summary() {
  local total_checks=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))

  section "Summary"
  printf '%sPASS=%s%s %sFAIL=%s%s %sWARN=%s%s TOTAL=%s MODE=%s\n' \
    "$GREEN$BOLD" "$PASS_COUNT" "$RESET" \
    "$RED$BOLD" "$FAIL_COUNT" "$RESET" \
    "$YELLOW$BOLD" "$WARN_COUNT" "$RESET" \
    "$total_checks" "$EXEC_MODE"
}

main() {
  resolve_exec_mode
  require_runtime_dependencies

  section "Observability Verification"
  note "Execution mode: ${EXEC_MODE}"
  if [[ "$EXEC_MODE" == "ssh" ]]; then
    note "SSH target: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}"
  fi

  check_prometheus_targets
  check_prometheus_metrics
  check_loki_logs
  check_tempo_traces
  check_grafana_datasources
  check_grafana_dashboards
  check_otel_collector
  emit_summary

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    exit 0
  fi

  exit 1
}

main
