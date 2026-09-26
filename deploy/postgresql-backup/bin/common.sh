#!/usr/bin/env bash

set -euo pipefail

readonly PROD_BACKUP_ROOT="/mnt/nvme-ssd/postgres-backups/automated"
readonly PROD_EXPECTED_MOUNT="/mnt/nvme-ssd"
readonly PROD_PGDATA="/mnt/nvme-ssd/postgres/main"
readonly PROD_CONFIG_DIR="/etc/postgresql/16/main"
readonly PROD_CONFIG_FILE="/etc/nem/postgresql-backup.conf"
readonly PROD_PATH="/usr/lib/postgresql/16/bin:/usr/sbin:/usr/bin:/sbin:/bin"
readonly GIB=$((1024 * 1024 * 1024))

if [[ "${NEM_BACKUP_TESTING:-0}" != "1" ]]; then
  PATH="$PROD_PATH"
  export PATH
  while IFS= read -r environment_name; do
    [[ "$environment_name" != NEM_BACKUP_* || "$environment_name" == "NEM_BACKUP_TESTING" ]] || {
      printf 'ERROR: unexpected production override: %s\n' "$environment_name" >&2
      exit 1
    }
  done < <(compgen -e)
fi

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}
require_pg16_tool() {
  local command="$1" version
  version="$("$command" --version)"
  [[ "$version" =~ PostgreSQL[^0-9]*16\. ]] || die "expected PostgreSQL 16 tool: $command"
}
validate_pg_toolchain() {
  local command
  for command in pg_basebackup pg_verifybackup pg_controldata psql pg_config; do
    require_command "$command"
    require_pg16_tool "$command"
  done
}

load_backup_config() {
  local config_file="${NEM_BACKUP_CONFIG:-$PROD_CONFIG_FILE}"
  local test_root="${NEM_BACKUP_TEST_ROOT:-}"

  if [[ "${NEM_BACKUP_TESTING:-0}" == "1" ]]; then
    [[ -n "$test_root" && "$test_root" != "/" ]] || die "test mode requires NEM_BACKUP_TEST_ROOT"
    test_root="$(realpath -e -- "$test_root")"
    config_file="$(realpath -e -- "$config_file")"
    [[ "$config_file" == "$test_root"/* ]] || die "test config must be below test root"
  else
    [[ -z "${NEM_BACKUP_TEST_ROOT:-}" ]] || die "test root is forbidden outside test mode"
    [[ "$config_file" == "$PROD_CONFIG_FILE" ]] || die "production config path is immutable"
    [[ ! -L "$config_file" ]] || die "config file must not be a symlink"
    [[ "$(stat -c '%u' -- "$config_file")" == "0" ]] || die "config file must be root-owned"
    (( (8#$(stat -c '%a' -- "$config_file") & 8#022) == 0 )) || die "config file is group/world writable"
  fi

  # shellcheck source=/dev/null
  source "$config_file"
  : "${BACKUP_ENABLED:?BACKUP_ENABLED is required}"
  : "${RETENTION_KEEP:?RETENTION_KEEP is required}"
  : "${FRESHNESS_MAX_SECONDS:?FRESHNESS_MAX_SECONDS is required}"
  : "${MAX_RATE:?MAX_RATE is required}"

  if [[ "${NEM_BACKUP_TESTING:-0}" == "1" ]]; then
    : "${BACKUP_ROOT:?test BACKUP_ROOT is required}"
    : "${EXPECTED_MOUNT:?test EXPECTED_MOUNT is required}"
    : "${PGDATA:?test PGDATA is required}"
    : "${CONFIG_DIR:?test CONFIG_DIR is required}"
    [[ "$BACKUP_ROOT" != "$PROD_BACKUP_ROOT" ]] || die "unsafe test backup root"
    BACKUP_ROOT="$(realpath -e -- "$BACKUP_ROOT")"
    PGDATA="$(realpath -e -- "$PGDATA")"
    CONFIG_DIR="$(realpath -e -- "$CONFIG_DIR")"
    [[ "$BACKUP_ROOT" == "$test_root"/* && "$BACKUP_ROOT" != "$PROD_BACKUP_ROOT" ]] || die "unsafe test backup root"
  else
    BACKUP_ROOT="$PROD_BACKUP_ROOT"
    EXPECTED_MOUNT="$PROD_EXPECTED_MOUNT"
    PGDATA="$PROD_PGDATA"
    CONFIG_DIR="$PROD_CONFIG_DIR"
  fi

  [[ "$BACKUP_ENABLED" == "true" || "$BACKUP_ENABLED" == "false" ]] || die "BACKUP_ENABLED must be true or false"
  [[ "$RETENTION_KEEP" =~ ^[1-9][0-9]*$ ]] || die "RETENTION_KEEP must be positive"
  [[ "$FRESHNESS_MAX_SECONDS" =~ ^[1-9][0-9]*$ ]] || die "FRESHNESS_MAX_SECONDS must be positive"
  [[ "$MAX_RATE" == "32M" ]] || die "MAX_RATE must be 32M"
}
expected_uid() {
  if [[ "${NEM_BACKUP_TESTING:-0}" == "1" ]]; then
    id -u
  else
    id -u postgres
  fi
}
validate_backup_root() {
  local uid expected_target backup_target expected_device backup_device expected_majmin backup_majmin
  [[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" ]] || die "backup root must be a real directory"
  [[ "$(realpath -e -- "$BACKUP_ROOT")" == "$BACKUP_ROOT" ]] || die "backup root canonical path mismatch"
  [[ -d "$EXPECTED_MOUNT" && ! -L "$EXPECTED_MOUNT" ]] || die "expected mount must be a real directory"
  [[ "$(realpath -e -- "$EXPECTED_MOUNT")" == "$EXPECTED_MOUNT" ]] || die "expected mount canonical path mismatch"
  [[ "$BACKUP_ROOT" == "$EXPECTED_MOUNT"/* ]] || die "backup root escaped expected mount"
  uid="$(expected_uid)"
  [[ "$(stat -c '%u' -- "$BACKUP_ROOT")" == "$uid" ]] || die "backup root has unexpected owner"
  [[ "$(stat -c '%a' -- "$BACKUP_ROOT")" == "700" ]] || die "backup root mode must be 700"
  expected_target="$(findmnt -n -o TARGET -T "$EXPECTED_MOUNT")" || die "expected mount is unavailable"
  [[ "$expected_target" == "$EXPECTED_MOUNT" ]] || die "expected mount resolves to $expected_target"
  backup_target="$(findmnt -n -o TARGET -T "$BACKUP_ROOT")" || die "backup mount is unavailable"
  [[ "$backup_target" == "$EXPECTED_MOUNT" || "$backup_target" == "$BACKUP_ROOT" ]] \
    || die "backup root has unapproved mount target: $backup_target"
  expected_device="$(stat -c '%d' -- "$EXPECTED_MOUNT")"
  backup_device="$(stat -c '%d' -- "$BACKUP_ROOT")"
  [[ "$backup_device" == "$expected_device" ]] || die "backup root is on the wrong filesystem device"
  expected_majmin="$(findmnt -n -o MAJ:MIN -T "$EXPECTED_MOUNT")" || die "expected filesystem identity is unavailable"
  backup_majmin="$(findmnt -n -o MAJ:MIN -T "$BACKUP_ROOT")" || die "backup filesystem identity is unavailable"
  [[ "$backup_majmin" == "$expected_majmin" ]] || die "backup root has the wrong filesystem identity"
}
validate_pgdata() {
  [[ -d "$PGDATA" && ! -L "$PGDATA" ]] || die "PGDATA must be a real directory"
  [[ "$(realpath -e -- "$PGDATA")" == "$PGDATA" ]] || die "PGDATA canonical path mismatch"
}

now_utc() {
  if [[ "${NEM_BACKUP_TESTING:-0}" == "1" && -n "${NEM_BACKUP_NOW:-}" ]]; then
    [[ "$NEM_BACKUP_NOW" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || die "invalid fake clock"
    printf '%s\n' "$NEM_BACKUP_NOW"
  else
    date -u +%Y%m%dT%H%M%SZ
  fi
}

epoch_now() {
  if [[ "${NEM_BACKUP_TESTING:-0}" == "1" && -n "${NEM_BACKUP_EPOCH:-}" ]]; then
    [[ "$NEM_BACKUP_EPOCH" =~ ^[0-9]+$ ]] || die "invalid fake epoch"
    printf '%s\n' "$NEM_BACKUP_EPOCH"
  else
    date -u +%s
  fi
}

state_dir_is_valid() {
  local state_dir="$BACKUP_ROOT/.state"
  [[ -d "$state_dir" && ! -L "$state_dir" ]] || return 1
  [[ "$(realpath -e -- "$state_dir")" == "$state_dir" ]] || return 1
  [[ "$(stat -c '%u' -- "$state_dir")" == "$(expected_uid)" ]] || return 1
  [[ "$(stat -c '%a' -- "$state_dir")" == "700" ]]
}

validate_state_dir() {
  state_dir_is_valid || die "state directory is missing or unsafe"
}

create_state_dir() {
  local state_dir="$BACKUP_ROOT/.state"
  if [[ -e "$state_dir" || -L "$state_dir" ]]; then
    validate_state_dir
    return
  fi
  mkdir -m 700 -- "$state_dir"
  validate_state_dir
}

state_descriptor_matches() {
  [[ -e "/proc/$$/fd/9" ]] || return 1
  [[ "$(stat -Lc '%d:%i' -- "/proc/$$/fd/9")" == "$(stat -Lc '%d:%i' -- "$BACKUP_ROOT/.state")" ]]
}

acquire_state_lock() {
  validate_state_dir
  if ! state_descriptor_matches; then
    exec 9<"$BACKUP_ROOT/.state"
    state_descriptor_matches || die "state lock descriptor mismatch"
  fi
  flock -n 9 || die "another backup or retention operation is active"
}

validate_state_file() {
  local path="$1"
  [[ "$(dirname -- "$path")" == "$BACKUP_ROOT/.state" ]] || die "state file escaped state directory"
  [[ -f "$path" && ! -L "$path" ]] || die "state file is missing or unsafe"
  [[ "$(stat -c '%u' -- "$path")" == "$(expected_uid)" ]] || die "state file has unexpected owner"
  [[ "$(stat -c '%a' -- "$path")" == "600" ]] || die "state file mode must be 600"
}

write_json_atomic() {
  local destination="$1" content="$2" temporary
  validate_state_dir
  [[ "$(dirname -- "$destination")" == "$BACKUP_ROOT/.state" ]] || die "metadata destination escaped state directory"
  if [[ -e "$destination" || -L "$destination" ]]; then
    validate_state_file "$destination"
  fi
  temporary="$(umask 077; mktemp --tmpdir="$BACKUP_ROOT/.state" ".${destination##*/}.tmp.XXXXXXXX")"
  if ! printf '%s\n' "$content" > "$temporary"; then
    rm -f -- "$temporary"
    return 1
  fi
  mv -fT -- "$temporary" "$destination"
}

estimated_required_bytes() {
  local data_bytes plus_floor doubled
  data_bytes="$(du -sB1 -- "$PGDATA" | cut -f1)"
  [[ "$data_bytes" =~ ^[0-9]+$ ]] || die "could not estimate PGDATA size"
  plus_floor=$((data_bytes + 64 * GIB))
  doubled=$((data_bytes * 2))
  (( plus_floor > doubled )) && printf '%s\n' "$plus_floor" || printf '%s\n' "$doubled"
}

assert_capacity() {
  local available required
  available="$(available_bytes "$BACKUP_ROOT")"
  required="$(estimated_required_bytes)"
  [[ "$available" =~ ^[0-9]+$ ]] || die "could not determine free space"
  (( available >= required )) || die "insufficient capacity: available=$available required=$required"
}

available_bytes() {
  df -B1 --output=avail "$1" | tail -n 1 | tr -d ' '
}

is_run_name() {
  [[ "$1" =~ ^basebackup-[0-9]{8}T[0-9]{6}Z$ ]]
}

is_verified_run() {
  local path="$1" run_id="${1##*/}" expected recorded_hash actual_hash
  is_run_name "$run_id" || return 1
  [[ -d "$path" && ! -L "$path" ]] || return 1
  [[ "$(dirname -- "$path")" == "$BACKUP_ROOT" ]] || return 1
  [[ "$(realpath -e -- "$path")" == "$path" ]] || return 1
  [[ "$(stat -c '%u' -- "$path")" == "$(expected_uid)" ]] || return 1
  [[ "$(stat -c '%a' -- "$path")" == "700" ]] || return 1
  [[ -d "$path/data" && ! -L "$path/data" ]] || return 1
  [[ "$(realpath -e -- "$path/data")" == "$path/data" ]] || return 1
  [[ -f "$path/data/backup_manifest" && ! -L "$path/data/backup_manifest" ]] || return 1
  [[ -f "$path/manifest.sha256" && ! -L "$path/manifest.sha256" ]] || return 1
  [[ -f "$path/OWNED-BY-NEM-POSTGRESQL-BACKUP" && ! -L "$path/OWNED-BY-NEM-POSTGRESQL-BACKUP" ]] || return 1
  [[ -f "$path/COMPLETED" && ! -L "$path/COMPLETED" ]] || return 1
  [[ -f "$path/verify.json" && ! -L "$path/verify.json" ]] || return 1
  [[ "$(<"$path/OWNED-BY-NEM-POSTGRESQL-BACKUP")" == "$run_id" ]] || return 1
  [[ "$(<"$path/COMPLETED")" == "$run_id" ]] || return 1
  expected="{\"schema\":1,\"run_id\":\"$run_id\",\"status\":\"verified\"}"
  [[ "$(<"$path/verify.json")" == "$expected" ]] || return 1
  recorded_hash="$(<"$path/manifest.sha256")"
  [[ "$recorded_hash" =~ ^[0-9a-f]{64}$ ]] || return 1
  actual_hash="$(sha256sum "$path/data/backup_manifest")"
  [[ "${actual_hash%% *}" == "$recorded_hash" ]]
}
