#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="nem"
REALM="nem"
CLIENT_ID="nem-mcp"
SSH_USER="${NEM_AUTH_SSH_USER:-sendo}"
SSH_HOST="${NEM_AUTH_SSH_HOST:-192.168.5.41}"
SSH_PORT="${NEM_AUTH_SSH_PORT:-2222}"
EXEC_MODE="${NEM_AUTH_MODE:-auto}"
FROM_HOST=false

VERBOSE=false
JSON_OUTPUT=false
PASS_COUNT=0
FAIL_COUNT=0
RESULTS_JSON='[]'
EXEC_TARGET=""

# Color codes
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

usage() {
  printf 'Usage: %s [--verbose] [--json] [--from-host]\n' "${0##*/}"
  printf '\n'
  printf 'Options:\n'
  printf '  --verbose   Include detailed per-test context\n'
  printf '  --json      Emit machine-readable JSON only\n'
  printf '  --from-host Use IngressRoute hostname (keycloak.nem.local) instead of K8s DNS\n'
  printf '  --help      Show this help\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  NEM_AUTH_MODE           auto | local | ssh (default: auto)\n'
  printf '  NEM_AUTH_SSH_USER       SSH user (default: sendo)\n'
  printf '  NEM_AUTH_SSH_HOST       SSH host (default: 192.168.5.41)\n'
  printf '  NEM_AUTH_SSH_PORT       SSH port (default: 2222)\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      ;;
    --json)
      JSON_OUTPUT=true
      ;;
    --from-host)
      FROM_HOST=true
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

# Determine Keycloak base URL
if [[ "$FROM_HOST" == true ]]; then
  KEYCLOAK_URL="http://keycloak.nem.local"
else
  KEYCLOAK_URL="http://keycloak:8080"
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
    *) printf '[%s]' "$status" ;;
  esac
}

append_json_result() {
  local test_name="$1"
  local status="$2"
  local message="$3"

  if [[ "$JSON_OUTPUT" == true ]]; then
    RESULTS_JSON="$(jq -cn \
      --argjson current "$RESULTS_JSON" \
      --arg test "$test_name" \
      --arg status "$status" \
      --arg message "$message" \
      '$current + [{test: $test, status: $status, message: $message}]')"
  fi
}

record_result() {
  local test_name="$1"
  local status="$2"
  local message="$3"

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac

  append_json_result "$test_name" "$status" "$message"

  if [[ "$JSON_OUTPUT" == false ]]; then
    printf '%s %-32s %s\n' "$(status_label "$status")" "$test_name" "$message"
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
      printf 'Invalid NEM_AUTH_MODE: %s\n' "$EXEC_MODE" >&2
      exit 2
      ;;
  esac
}

resolve_exec_target() {
  local candidates=(
    "deploy/nem-mcp"
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
}

exec_curl() {
  local url="$1"
  local method="${2:-GET}"
  local extra_args="${3:-}"

  if [[ -z "$EXEC_TARGET" ]]; then
    return 1
  fi

  local curl_cmd="curl -s -X ${method}"
  if [[ -n "$extra_args" ]]; then
    curl_cmd="${curl_cmd} ${extra_args}"
  fi
  curl_cmd="${curl_cmd} '${url}'"

  run_target "kubectl exec -n ${NAMESPACE} ${EXEC_TARGET} -- ${curl_cmd}"
}

# Test 1: dev-admin user authentication
test_dev_admin() {
  local test_name="Test 1: dev-admin (realm admin)"
  local token_url="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
  local response

  note "Authenticating dev-admin with realm admin role"
  
  response="$(exec_curl "${token_url}" "POST" \
    "-H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=password&client_id=${CLIENT_ID}&username=dev-admin&password=dev-password'" || true)"

  note "Response: $response"

  if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
    local access_token=$(echo "$response" | jq -r '.access_token')
    note "Got access token: ${access_token:0:20}..."

    # Decode the token and check for admin role
    local decoded=$(echo "$access_token" | cut -d. -f2 | base64 -d 2>/dev/null || true)
    note "Token payload: $decoded"

    if echo "$decoded" | jq -e '.realm_access.roles | map(select(. == "admin")) | length > 0' >/dev/null 2>&1; then
      record_result "$test_name" "PASS" "dev-admin authenticated with admin role"
    else
      record_result "$test_name" "FAIL" "dev-admin has no admin role in token"
    fi
  else
    local error=$(echo "$response" | jq -r '.error // "unknown error"' 2>/dev/null || echo "invalid JSON")
    record_result "$test_name" "FAIL" "Authentication failed: $error"
  fi
}

# Test 2: Admin user authentication (from bootstrap Job)
test_admin_user() {
  local test_name="Test 2: Admin (global admin from bootstrap)"
  local token_url="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
  local response

  note "Authenticating Admin with global admin role"

  response="$(exec_curl "${token_url}" "POST" \
    "-H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=password&client_id=${CLIENT_ID}&username=Admin&password=admin'" || true)"

  note "Response: $response"

  if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
    local access_token=$(echo "$response" | jq -r '.access_token')
    note "Got access token: ${access_token:0:20}..."

    # Decode the token and check for admin role
    local decoded=$(echo "$access_token" | cut -d. -f2 | base64 -d 2>/dev/null || true)
    note "Token payload: $decoded"

    if echo "$decoded" | jq -e '.realm_access.roles | map(select(. == "admin")) | length > 0' >/dev/null 2>&1; then
      record_result "$test_name" "PASS" "Admin authenticated with admin role"
    else
      record_result "$test_name" "FAIL" "Admin has no admin role in token"
    fi
  else
    local error=$(echo "$response" | jq -r '.error // "unknown error"' 2>/dev/null || echo "invalid JSON")
    record_result "$test_name" "FAIL" "Authentication failed: $error"
  fi
}

# Test 3: Spring user authentication (standard user)
test_spring_user() {
  local test_name="Test 3: Spring (standard user)"
  local token_url="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
  local response

  note "Authenticating Spring as standard user"

  response="$(exec_curl "${token_url}" "POST" \
    "-H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=password&client_id=${CLIENT_ID}&username=Spring&password=spring'" || true)"

  note "Response: $response"

  if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
    local access_token=$(echo "$response" | jq -r '.access_token')
    note "Got access token: ${access_token:0:20}..."

    # Decode the token and check for user role but NOT admin
    local decoded=$(echo "$access_token" | cut -d. -f2 | base64 -d 2>/dev/null || true)
    note "Token payload: $decoded"

    local has_user=$(echo "$decoded" | jq -e '.realm_access.roles | map(select(. == "user")) | length > 0' >/dev/null 2>&1 && echo "true" || echo "false")
    local has_admin=$(echo "$decoded" | jq -e '.realm_access.roles | map(select(. == "admin")) | length > 0' >/dev/null 2>&1 && echo "true" || echo "false")

    if [[ "$has_user" == "true" && "$has_admin" == "false" ]]; then
      record_result "$test_name" "PASS" "Spring has user role, no admin role"
    else
      record_result "$test_name" "FAIL" "Spring role mismatch: user=$has_user admin=$has_admin (expected: user=true admin=false)"
    fi
  else
    local error=$(echo "$response" | jq -r '.error // "unknown error"' 2>/dev/null || echo "invalid JSON")
    record_result "$test_name" "FAIL" "Authentication failed: $error"
  fi
}

# Test 4: Token introspection via userinfo endpoint
test_token_introspection() {
  local test_name="Test 4: Token introspection (userinfo)"
  local token_url="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
  local userinfo_url="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/userinfo"
  local auth_response

  note "Obtaining access token for Spring user"

  auth_response="$(exec_curl "${token_url}" "POST" \
    "-H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=password&client_id=${CLIENT_ID}&username=Spring&password=spring'" || true)"

  note "Auth response: $auth_response"

  if echo "$auth_response" | jq -e '.access_token' >/dev/null 2>&1; then
    local access_token=$(echo "$auth_response" | jq -r '.access_token')
    note "Got access token: ${access_token:0:20}..."

    note "Calling userinfo endpoint"

    local userinfo_response=$(exec_curl "${userinfo_url}" "GET" \
      "-H 'Authorization: Bearer ${access_token}'" || true)

    note "Userinfo response: $userinfo_response"

    if echo "$userinfo_response" | jq -e '.sub' >/dev/null 2>&1; then
      local username=$(echo "$userinfo_response" | jq -r '.preferred_username // .sub' 2>/dev/null || echo "unknown")
      record_result "$test_name" "PASS" "Userinfo retrieved for user: $username"
    else
      local error=$(echo "$userinfo_response" | jq -r '.error // "invalid response"' 2>/dev/null || echo "invalid JSON")
      record_result "$test_name" "FAIL" "Userinfo lookup failed: $error"
    fi
  else
    local error=$(echo "$auth_response" | jq -r '.error // "unknown error"' 2>/dev/null || echo "invalid JSON")
    record_result "$test_name" "FAIL" "Initial auth failed: $error"
  fi
}

# Test 5: Invalid credentials (negative test)
test_invalid_credentials() {
  local test_name="Test 5: Invalid credentials (negative test)"
  local token_url="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
  local response

  note "Attempting auth with invalid password"

  response="$(exec_curl "${token_url}" "POST" \
    "-H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=password&client_id=${CLIENT_ID}&username=dev-admin&password=wrongpassword'" || true)"

  note "Response: $response"

  if ! echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
    local error=$(echo "$response" | jq -r '.error // "no error field"' 2>/dev/null || echo "invalid JSON")
    if [[ -n "$error" && "$error" != "null" && "$error" != "no error field" ]]; then
      record_result "$test_name" "PASS" "Invalid credentials rejected: $error"
    else
      record_result "$test_name" "FAIL" "Expected error response, got unexpected format"
    fi
  else
    record_result "$test_name" "FAIL" "Invalid credentials were incorrectly accepted"
  fi
}

# Main execution
main() {
  section "Authentication Test Suite"

  resolve_exec_mode
  note "Execution mode: $EXEC_MODE"

  resolve_exec_target
  if [[ -z "$EXEC_TARGET" ]]; then
    printf '%s\n' "ERROR: Could not resolve exec target (no kubectl or pod found)" >&2
    exit 1
  fi
  note "Exec target: $EXEC_TARGET"

  note "Keycloak URL: $KEYCLOAK_URL"
  note "Realm: $REALM"
  note "Client ID: $CLIENT_ID"

  section "Running authentication tests"

  test_dev_admin
  test_admin_user
  test_spring_user
  test_token_introspection
  test_invalid_credentials

  section "Test Summary"

  if [[ "$JSON_OUTPUT" == true ]]; then
    jq -n \
      --argjson results "$RESULTS_JSON" \
      --arg pass "$PASS_COUNT" \
      --arg fail "$FAIL_COUNT" \
      '{tests: $results, summary: {pass: ($pass | tonumber), fail: ($fail | tonumber)}}'
  else
    printf '%s%-10s %d\n' "$(status_label "PASS")" " " "$PASS_COUNT"
    printf '%s%-10s %d\n' "$(status_label "FAIL")" " " "$FAIL_COUNT"
  fi

  if [[ $FAIL_COUNT -gt 0 ]]; then
    if [[ "$JSON_OUTPUT" == false ]]; then
      printf '\n%sAuthentication tests FAILED%s\n' "$RED$BOLD" "$RESET"
    fi
    exit 1
  else
    if [[ "$JSON_OUTPUT" == false ]]; then
      printf '\n%sAll authentication tests PASSED%s\n' "$GREEN$BOLD" "$RESET"
    fi
    exit 0
  fi
}

main "$@"
