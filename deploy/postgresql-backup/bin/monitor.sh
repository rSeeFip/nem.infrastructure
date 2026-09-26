#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/common.sh
source "$SCRIPT_DIR/common.sh"

json_number() {
  local file="$1" field="$2" value
  value="$(tr -d '\n' < "$file" | sed -n "s/.*\"$field\":\([0-9][0-9]*\).*/\1/p")"
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$value"
}

json_run_id() {
  local file="$1" value
  value="$(tr -d '\n' < "$file" | sed -n 's/.*"run_id":"\(basebackup-[0-9]\{8\}T[0-9]\{6\}Z\)".*/\1/p')"
  is_run_name "$value" || return 1
  printf '%s\n' "$value"
}

json_failure_run_id() {
  local file="$1" value
  value="$(tr -d '\n' < "$file" | sed -n 's/.*"run_id":"\([^"]*\)".*/\1/p')"
  [[ "$value" == "unknown" ]] || is_run_name "$value" || return 1
  printf '%s\n' "$value"
}

main() {
  local success_file failure_file success_epoch failure_epoch current run_id failure_run_id age expected
  for command in df du findmnt realpath sed sha256sum; do require_command "$command"; done
  load_backup_config
  [[ "$BACKUP_ENABLED" == "true" ]] || die "backup automation is disabled"
  validate_backup_root
  validate_pgdata
  validate_state_dir
  success_file="$BACKUP_ROOT/.state/last-success.json"
  failure_file="$BACKUP_ROOT/.state/last-failure.json"
  validate_state_file "$success_file"
  success_epoch="$(json_number "$success_file" epoch)" || die "last-success metadata is malformed"
  run_id="$(json_run_id "$success_file")" || die "last-success run id is malformed"
  expected="{\"schema\":1,\"run_id\":\"$run_id\",\"status\":\"verified\",\"epoch\":$success_epoch}"
  [[ "$(<"$success_file")" == "$expected" ]] || die "last-success metadata is malformed"
  is_verified_run "$BACKUP_ROOT/$run_id" || die "last-success does not reference a verified run"
  current="$(epoch_now)"
  ((current >= success_epoch)) || die "last-success timestamp is in the future"
  age=$((current - success_epoch))
  ((age <= FRESHNESS_MAX_SECONDS)) || die "latest verified backup is stale: age=$age"
  if [[ -e "$failure_file" || -L "$failure_file" ]]; then
    validate_state_file "$failure_file"
    failure_epoch="$(json_number "$failure_file" epoch)" || die "last-failure metadata is malformed"
    failure_run_id="$(json_failure_run_id "$failure_file")" || die "last-failure run id is malformed"
    expected="{\"schema\":1,\"run_id\":\"$failure_run_id\",\"status\":\"failed\",\"epoch\":$failure_epoch}"
    [[ "$(<"$failure_file")" == "$expected" ]] || die "last-failure metadata is malformed"
    ((failure_epoch < success_epoch)) || die "a backup failure occurred at or after the last success"
  fi
  assert_capacity
  printf 'PostgreSQL backup healthy: run=%s age_seconds=%s\n' "$run_id" "$age"
}

main "$@"
