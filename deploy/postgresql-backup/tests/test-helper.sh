#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/.." && pwd)"
BIN_DIR="$PROJECT_DIR/bin"
MOCK_DIR="$TEST_DIR/mocks"
export BIN_DIR

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_exists() {
  [[ -e "$1" ]] || fail "expected path to exist: $1"
}

assert_not_exists() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"
}

assert_contains() {
  grep -F -- "$2" "$1" >/dev/null || fail "expected $1 to contain: $2"
}

run_fails() {
  if "$@" >"$FIXTURE/output" 2>&1; then
    fail "command unexpectedly succeeded: $*"
  fi
}

setup_fixture() {
  FIXTURE="$(mktemp -d)"
  export FIXTURE
  export BACKUP_ROOT="$FIXTURE/backups"
  export EXPECTED_MOUNT="$FIXTURE"
  export PGDATA="$FIXTURE/pgdata"
  export CONFIG_DIR="$FIXTURE/config"
  export MOCK_LOG="$FIXTURE/mock.log"
  export NEM_BACKUP_TESTING=1
  export NEM_BACKUP_TEST_ROOT="$FIXTURE"
  export NEM_BACKUP_CONFIG="$FIXTURE/backup.conf"
  export NEM_BACKUP_NOW=20260926T020000Z
  export NEM_BACKUP_EPOCH=1790388000
  export PATH="$MOCK_DIR:$ORIGINAL_PATH"
  unset MOCK_AVAILABLE_BYTES MOCK_DATA_BYTES MOCK_PGDATA MOCK_RECOVERY MOCK_MAJOR
  unset MOCK_TABLESPACES MOCK_BASEBACKUP_FAIL MOCK_VERIFY_FAIL MOCK_VERIFY_FAIL_CALL
  unset MOCK_PG_VERSION MOCK_FILE_SETTINGS_ERROR MOCK_HBA_ERROR MOCK_IDENT_ERROR
  unset MOCK_FILE_SETTINGS_FILES MOCK_HBA_FILES MOCK_IDENT_FILES
  unset MOCK_FIND_FAIL_AFTER_PREFIX MOCK_PSQL_ACTIVE_LIST_FAIL MOCK_PSQL_DATABASE_LIST_FAIL
  unset MOCK_EXPECTED_TARGET MOCK_BACKUP_TARGET MOCK_EXPECTED_MAJMIN MOCK_BACKUP_MAJMIN
  unset MOCK_FINDMNT_MISSING_EXPECTED MOCK_EXPECTED_DEVICE MOCK_BACKUP_DEVICE
  mkdir -p "$BACKUP_ROOT" "$PGDATA" "$CONFIG_DIR"
  chmod 700 "$BACKUP_ROOT"
  printf '16\n' > "$PGDATA/PG_VERSION"
  printf 'config\n' > "$CONFIG_DIR/postgresql.conf"
  printf 'hba\n' > "$CONFIG_DIR/pg_hba.conf"
  printf 'ident\n' > "$CONFIG_DIR/pg_ident.conf"
  mkdir "$CONFIG_DIR/conf.d"
  printf 'included\n' > "$CONFIG_DIR/conf.d/10-local.conf"
  : > "$MOCK_LOG"
  write_config 7 129600 true
}

write_config() {
  cat > "$NEM_BACKUP_CONFIG" <<EOF
BACKUP_ENABLED=$3
RETENTION_KEEP=$1
FRESHNESS_MAX_SECONDS=$2
MAX_RATE=32M
BACKUP_ROOT=$BACKUP_ROOT
EXPECTED_MOUNT=$EXPECTED_MOUNT
PGDATA=$PGDATA
CONFIG_DIR=$CONFIG_DIR
EOF
}

teardown_fixture() {
  rm -rf -- "$FIXTURE"
}

make_verified_run() {
  local run_id="$1" path
  path="$BACKUP_ROOT/$run_id"
  mkdir -m 700 -- "$path"
  mkdir -m 700 -- "$path/data"
  printf '{"PostgreSQL-Backup-Manifest-Version": 2}\n' > "$path/data/backup_manifest"
  sha256sum "$path/data/backup_manifest" | cut -d ' ' -f1 > "$path/manifest.sha256"
  printf '%s\n' "$run_id" > "$path/OWNED-BY-NEM-POSTGRESQL-BACKUP"
  printf '%s\n' "$run_id" > "$path/COMPLETED"
  printf '{"schema":1,"run_id":"%s","status":"verified"}\n' "$run_id" > "$path/verify.json"
  chmod 600 "$path/OWNED-BY-NEM-POSTGRESQL-BACKUP" "$path/COMPLETED" "$path/verify.json" "$path/manifest.sha256" "$path/data/backup_manifest"
}

write_last_success() {
  local run_id="$1" epoch="$2"
  mkdir -p "$BACKUP_ROOT/.state"
  chmod 700 "$BACKUP_ROOT/.state"
  printf '{"schema":1,"run_id":"%s","status":"verified","epoch":%s}\n' "$run_id" "$epoch" > "$BACKUP_ROOT/.state/last-success.json"
  chmod 600 "$BACKUP_ROOT/.state/last-success.json"
}

ORIGINAL_PATH="$PATH"
export ORIGINAL_PATH
