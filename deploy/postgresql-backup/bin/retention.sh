#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/common.sh
source "$SCRIPT_DIR/common.sh"

main() {
  local -a runs=()
  local -a verified_runs=()
  local path latest index remove_count quarantine runs_inventory

  load_backup_config
  validate_backup_root
  for command in find flock mktemp pg_verifybackup sha256sum sort stat; do require_command "$command"; done
  require_pg16_tool pg_verifybackup
  create_state_dir
  acquire_state_lock

  runs_inventory="$(umask 077; mktemp --tmpdir="$BACKUP_ROOT/.state" .runs.XXXXXXXX)"
  if ! find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'basebackup-*' -print0 \
    | sort -z > "$runs_inventory"; then
    rm -f -- "$runs_inventory"
    die "could not enumerate backup runs"
  fi
  while IFS= read -r -d '' path; do
    [[ ! -L "$path" ]] || continue
    runs+=("$path")
  done < "$runs_inventory"
  rm -f -- "$runs_inventory"

  ((${#runs[@]} > 0)) || return 0
  latest="${runs[${#runs[@]} - 1]}"
  is_verified_run "$latest" || die "latest run is not fully verified; refusing retention"

  for path in "${runs[@]}"; do
    if is_verified_run "$path"; then
      verified_runs+=("$path")
    else
      printf 'Skipping malformed or unverified retention candidate: %s\n' "${path##*/}" >&2
    fi
  done

  remove_count=$((${#verified_runs[@]} - RETENTION_KEEP))
  ((remove_count > 0)) || return 0
  pg_verifybackup "$latest/data" >/dev/null

  for ((index = 0; index < remove_count; index++)); do
    path="${verified_runs[$index]}"
    [[ "$(dirname -- "$path")" == "$BACKUP_ROOT" ]] || die "retention candidate escaped backup root"
    quarantine="$BACKUP_ROOT/.pruning-${path##*/}-$$"
    [[ ! -e "$quarantine" && ! -L "$quarantine" ]] || die "quarantine path already exists"
    mv -T -- "$path" "$quarantine"
    rm -rf --one-file-system -- "$quarantine"
  done
}

main "$@"
