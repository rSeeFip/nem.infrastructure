#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/test-helper.sh
source "$TEST_DIR/test-helper.sh"

setup_fixture
bash "$BIN_DIR/backup.sh" > "$FIXTURE/output"
run="$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW"
assert_exists "$run/COMPLETED"
assert_exists "$run/data/backup_manifest"
assert_exists "$run/manifest.sha256"
assert_exists "$run/support/pg_controldata.txt"
assert_exists "$run/support/config/conf.d/10-local.conf"
assert_exists "$BACKUP_ROOT/.state/last-success.json"
[[ "$(stat -c '%a' "$run/verify.json")" == "600" ]] || fail "verify metadata is not private"
assert_contains "$MOCK_LOG" "--format=plain --wal-method=stream --checkpoint=spread --manifest-checksums=SHA256 --max-rate=32M --no-password"
teardown_fixture

setup_fixture
ln -s /etc/passwd "$CONFIG_DIR/conf.d/unsafe-link"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "configuration tree contains unsafe entry"
teardown_fixture

setup_fixture
export MOCK_FIND_FAIL_AFTER_PREFIX=1
run_fails bash "$BIN_DIR/backup.sh"
assert_not_exists "$BACKUP_ROOT/.state/last-success.json"
assert_not_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW"
assert_contains "$FIXTURE/output" "could not enumerate configuration tree"
teardown_fixture

setup_fixture
export MOCK_PSQL_ACTIVE_LIST_FAIL=1
run_fails bash "$BIN_DIR/backup.sh"
assert_not_exists "$BACKUP_ROOT/.state/last-success.json"
assert_not_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW"
assert_contains "$FIXTURE/output" "could not enumerate active configuration"
teardown_fixture

setup_fixture
export MOCK_PSQL_DATABASE_LIST_FAIL=1
run_fails bash "$BIN_DIR/backup.sh"
assert_not_exists "$BACKUP_ROOT/.state/last-success.json"
assert_not_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW"
assert_contains "$FIXTURE/output" "could not enumerate databases"
teardown_fixture

setup_fixture
mkfifo "$CONFIG_DIR/conf.d/unsafe-fifo"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "configuration tree contains unsafe entry"
teardown_fixture

setup_fixture
printf 'external\n' > "$FIXTURE/external-postgresql.conf"
export MOCK_FILE_SETTINGS_FILES="$FIXTURE/external-postgresql.conf"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "active configuration escaped CONFIG_DIR"
teardown_fixture

setup_fixture
export MOCK_HBA_ERROR=1
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "pg_hba_file_rules reports errors"
teardown_fixture

setup_fixture
export MOCK_FILE_SETTINGS_ERROR=1
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "pg_file_settings reports errors"
teardown_fixture

setup_fixture
export MOCK_IDENT_ERROR=1
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "pg_ident_file_mappings reports errors"
teardown_fixture

setup_fixture
printf 'external\n' > "$FIXTURE/external-hba.conf"
export MOCK_HBA_FILES="$FIXTURE/external-hba.conf"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "active HBA configuration escaped CONFIG_DIR"
teardown_fixture

setup_fixture
printf 'external\n' > "$FIXTURE/external-ident.conf"
export MOCK_IDENT_FILES="$FIXTURE/external-ident.conf"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "active ident configuration escaped CONFIG_DIR"
teardown_fixture

setup_fixture
printf 'external-user\n' > "$FIXTURE/external-users"
printf 'local @%s all peer\n' "$FIXTURE/external-users" > "$CONFIG_DIR/pg_hba.conf"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "HBA @file escaped CONFIG_DIR"
teardown_fixture

setup_fixture
printf '@nested-users\n' > "$CONFIG_DIR/conf.d/users"
printf 'postgres\n' > "$CONFIG_DIR/conf.d/nested-users"
printf 'local @conf.d/users all peer\n' > "$CONFIG_DIR/pg_hba.conf"
bash "$BIN_DIR/backup.sh" > "$FIXTURE/output"
assert_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW/support/config/conf.d/nested-users"
teardown_fixture

setup_fixture
printf 'postgres\n' > "$CONFIG_DIR/conf.d/users#list"
printf 'local @"conf.d/users#list" all peer\n' > "$CONFIG_DIR/pg_hba.conf"
bash "$BIN_DIR/backup.sh" > "$FIXTURE/output"
assert_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW/support/config/conf.d/users#list"
teardown_fixture

setup_fixture
export MOCK_PG_VERSION=15.9
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "expected PostgreSQL 16 tool"
teardown_fixture

setup_fixture
mkdir -m 700 "$BACKUP_ROOT/.state"
printf 'unchanged\n' > "$FIXTURE/legacy-lock-target"
ln -s "$FIXTURE/legacy-lock-target" "$BACKUP_ROOT/.state/backup.lock"
bash "$BIN_DIR/backup.sh" > "$FIXTURE/output"
[[ "$(<"$FIXTURE/legacy-lock-target")" == "unchanged" ]] || fail "legacy lock symlink target was modified"
teardown_fixture

setup_fixture
export MOCK_TABLESPACES=1
run_fails bash "$BIN_DIR/backup.sh"
assert_not_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW"
assert_contains "$BACKUP_ROOT/.state/last-failure.json" '"status":"failed"'
teardown_fixture

setup_fixture
export MOCK_AVAILABLE_BYTES=1024
run_fails bash "$BIN_DIR/backup.sh"
[[ ! -s "$MOCK_LOG" || "$(grep '^pg_basebackup ' "$MOCK_LOG" | grep -vc -- '--version' || true)" == "0" ]] || fail "base backup ran without capacity"
teardown_fixture

setup_fixture
rm "$CONFIG_DIR/postgresql.conf"
ln -s /etc/passwd "$CONFIG_DIR/postgresql.conf"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "configuration tree contains unsafe entry"
teardown_fixture

setup_fixture
export MOCK_VERIFY_FAIL=1
run_fails bash "$BIN_DIR/backup.sh"
assert_not_exists "$BACKUP_ROOT/basebackup-$NEM_BACKUP_NOW"
assert_exists "$BACKUP_ROOT/.basebackup-$NEM_BACKUP_NOW.inprogress"
assert_not_exists "$BACKUP_ROOT/.basebackup-$NEM_BACKUP_NOW.inprogress/manifest.sha256"
teardown_fixture

setup_fixture
sed -i "s|BACKUP_ROOT=.*|BACKUP_ROOT=/mnt/nvme-ssd/postgres-backups/automated|" "$NEM_BACKUP_CONFIG"
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$FIXTURE/output" "unsafe test backup root"
teardown_fixture

setup_fixture
state_target="$FIXTURE/state-target"
mkdir -m 755 "$state_target"
ln -s "$state_target" "$BACKUP_ROOT/.state"
run_fails bash "$BIN_DIR/backup.sh"
[[ "$(stat -c '%a' "$state_target")" == "755" ]] || fail "unsafe state symlink target mode was changed"
assert_not_exists "$state_target/backup.lock"
teardown_fixture

setup_fixture
mkdir -m 755 "$BACKUP_ROOT/.state"
run_fails bash "$BIN_DIR/backup.sh"
[[ "$(stat -c '%a' "$BACKUP_ROOT/.state")" == "755" ]] || fail "unsafe state directory mode was changed"
teardown_fixture

setup_fixture
mkdir -m 700 "$BACKUP_ROOT/.state"
printf 'unchanged\n' > "$FIXTURE/sentinel"
bash -c '
  source "$1"
  destination="$BACKUP_ROOT/.state/result.json"
  trap_path="${destination}.tmp.$$"
  ln -s "$FIXTURE/sentinel" "$trap_path"
  write_json_atomic "$destination" "{\"ok\":true}"
' _ "$BIN_DIR/common.sh"
[[ "$(<"$FIXTURE/sentinel")" == "unchanged" ]] || fail "atomic metadata write followed a pre-existing temporary symlink"
[[ -f "$BACKUP_ROOT/.state/result.json" && ! -L "$BACKUP_ROOT/.state/result.json" ]] || fail "atomic metadata destination is unsafe"
teardown_fixture

printf 'backup tests passed\n'
