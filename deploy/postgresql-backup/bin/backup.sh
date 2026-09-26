#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=bin/config-capture.sh
source "$SCRIPT_DIR/config-capture.sh"

success=0
run_id="unknown"

record_failure() {
  ((success == 1)) && return 0
  if [[ -n "${BACKUP_ROOT:-}" && -d "${BACKUP_ROOT:-}" && ! -L "${BACKUP_ROOT:-}" ]] && state_dir_is_valid; then
    write_json_atomic "$BACKUP_ROOT/.state/last-failure.json" \
      "{\"schema\":1,\"run_id\":\"$run_id\",\"status\":\"failed\",\"epoch\":$(epoch_now)}" || true
  fi
}

capture_support_inventory() {
  local target="$1" database database_inventory
  mkdir -m 700 -- "$target"
  capture_postgresql_config "$target/config" "$target"

  (umask 077; psql -XAt --dbname=postgres -c \
    "SELECT datname || '|' || pg_encoding_to_char(encoding) || '|' || datcollate || '|' || datctype FROM pg_database ORDER BY datname" \
    > "$target/databases.txt")
  (umask 077; psql -XAt --dbname=postgres -c \
    "SELECT rolname || '|' || rolsuper || '|' || rolcreaterole || '|' || rolcreatedb || '|' || rolcanlogin || '|' || rolreplication FROM pg_roles ORDER BY rolname" \
    > "$target/roles.txt")
  (umask 077; psql -XAt --dbname=postgres -c \
    "SELECT name || '|' || setting FROM pg_settings WHERE name IN ('shared_preload_libraries','session_preload_libraries','wal_level','archive_mode') ORDER BY name" \
    > "$target/server-settings.txt")
  : > "$target/extensions.txt"
  chmod 600 -- "$target/extensions.txt"
  database_inventory="$(umask 077; mktemp --tmpdir="$target" .databases.XXXXXXXX)"
  if ! psql -XAt --dbname=postgres -c \
    "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname" \
    > "$database_inventory"; then
    rm -f -- "$database_inventory"
    die "could not enumerate databases"
  fi
  while IFS= read -r database; do
    (umask 077; psql -XAt --dbname="$database" -c \
      "SELECT current_database() || '|' || extname || '|' || extversion FROM pg_extension ORDER BY extname" \
      >> "$target/extensions.txt")
  done < "$database_inventory"
  rm -f -- "$database_inventory"
  (umask 077; pg_controldata "$PGDATA" > "$target/pg_controldata.txt")
  (umask 077; pg_config --version > "$target/pg-version.txt")
  chmod 600 -- "$target"/*.txt
}

database_preflight() {
  local actual_data in_recovery tablespaces version
  actual_data="$(psql -XAt --dbname=postgres -c 'SHOW data_directory')"
  [[ "$actual_data" == "$PGDATA" ]] || die "connected primary uses unexpected data directory"
  in_recovery="$(psql -XAt --dbname=postgres -c 'SELECT pg_is_in_recovery()')"
  [[ "$in_recovery" == "f" ]] || die "connected server is not the primary"
  version="$(psql -XAt --dbname=postgres -c "SELECT current_setting('server_version_num')::int / 10000")"
  [[ "$version" == "16" ]] || die "expected PostgreSQL major version 16"
  tablespaces="$(psql -XAt --dbname=postgres -c "SELECT count(*) FROM pg_tablespace WHERE spcname NOT IN ('pg_default','pg_global')")"
  [[ "$tablespaces" == "0" ]] || die "external tablespaces are not supported"
}

main() {
  local timestamp temporary final failure_file
  trap record_failure EXIT
  for command in df du find findmnt flock install mktemp realpath sha256sum stat; do
    require_command "$command"
  done
  validate_pg_toolchain
  load_backup_config
  [[ "$BACKUP_ENABLED" == "true" ]] || die "backup automation is disabled"
  validate_backup_root
  validate_pgdata
  [[ "$(id -u)" == "$(expected_uid)" ]] || die "backup must run as the expected OS user"
  create_state_dir
  acquire_state_lock

  database_preflight
  assert_capacity
  timestamp="$(now_utc)"
  run_id="basebackup-$timestamp"
  temporary="$BACKUP_ROOT/.${run_id}.inprogress"
  final="$BACKUP_ROOT/$run_id"
  [[ ! -e "$temporary" && ! -L "$temporary" && ! -e "$final" && ! -L "$final" ]] || die "run path already exists"
  mkdir -m 700 -- "$temporary"
  (umask 077; printf '%s\n' "$run_id" > "$temporary/OWNED-BY-NEM-POSTGRESQL-BACKUP")
  capture_support_inventory "$temporary/support"

  pg_basebackup --pgdata="$temporary/data" --format=plain --wal-method=stream \
    --checkpoint=spread --manifest-checksums=SHA256 --max-rate="$MAX_RATE" --no-password --progress
  (umask 077; pg_verifybackup "$temporary/data" > "$temporary/verify.log")
  (umask 077; sha256sum "$temporary/data/backup_manifest" | cut -d ' ' -f1 > "$temporary/manifest.sha256")
  (umask 077; printf '{"schema":1,"run_id":"%s","status":"verified"}\n' "$run_id" > "$temporary/verify.json")
  (umask 077; printf '%s\n' "$run_id" > "$temporary/COMPLETED")
  chmod -R u=rwX,go= -- "$temporary"
  mv -T -- "$temporary" "$final"
  "$SCRIPT_DIR/retention.sh"
  write_json_atomic "$BACKUP_ROOT/.state/last-success.json" \
    "{\"schema\":1,\"run_id\":\"$run_id\",\"status\":\"verified\",\"epoch\":$(epoch_now)}"
  failure_file="$BACKUP_ROOT/.state/last-failure.json"
  if [[ -e "$failure_file" || -L "$failure_file" ]]; then
    validate_state_file "$failure_file"
    rm -f -- "$failure_file"
  fi
  success=1
  printf 'Verified PostgreSQL physical backup completed: %s\n' "$run_id"
}

main "$@"
