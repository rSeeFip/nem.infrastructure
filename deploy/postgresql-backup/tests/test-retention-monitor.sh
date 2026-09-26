#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/test-helper.sh
source "$TEST_DIR/test-helper.sh"

setup_fixture
for day in 01 02 03 04 05 06 07 08 09; do make_verified_run "basebackup-202609${day}T020000Z"; done
mkdir "$BACKUP_ROOT/manual-backup" "$BACKUP_ROOT/basebackup-20260900T020000Z"
touch "$BACKUP_ROOT/basebackup-20260900T020000Z/COMPLETED"
ln -s "$BACKUP_ROOT/basebackup-20260909T020000Z" "$BACKUP_ROOT/basebackup-20260910T020000Z-link"
bash "$BIN_DIR/retention.sh"
assert_contains "$MOCK_LOG" "pg_verifybackup $BACKUP_ROOT/basebackup-20260909T020000Z/data"
assert_not_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
assert_not_exists "$BACKUP_ROOT/basebackup-20260902T020000Z"
assert_exists "$BACKUP_ROOT/basebackup-20260903T020000Z"
assert_exists "$BACKUP_ROOT/manual-backup"
assert_exists "$BACKUP_ROOT/basebackup-20260900T020000Z"
assert_exists "$BACKUP_ROOT/basebackup-20260910T020000Z-link"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
export MOCK_FIND_FAIL_AFTER_PREFIX=1
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
assert_contains "$FIXTURE/output" "could not enumerate backup runs"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
latest="$BACKUP_ROOT/basebackup-20260908T020000Z"
rm -rf "$latest/data"
mkdir -m 700 "$latest/data"
rm "$latest/manifest.sha256"
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
write_last_success "basebackup-20260908T020000Z" 1790388000
run_fails bash "$BIN_DIR/monitor.sh"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
latest="$BACKUP_ROOT/basebackup-20260908T020000Z"
rm -rf "$latest/data"
ln -s "$BACKUP_ROOT/basebackup-20260907T020000Z/data" "$latest/data"
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
write_last_success "basebackup-20260908T020000Z" 1790388000
run_fails bash "$BIN_DIR/monitor.sh"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
latest="$BACKUP_ROOT/basebackup-20260908T020000Z"
printf 'changed\n' >> "$latest/data/backup_manifest"
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
write_last_success "basebackup-20260908T020000Z" 1790388000
run_fails bash "$BIN_DIR/monitor.sh"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
export MOCK_VERIFY_FAIL=1
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
assert_contains "$MOCK_LOG" "pg_verifybackup $BACKUP_ROOT/basebackup-20260908T020000Z/data"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
mkdir "$BACKUP_ROOT/basebackup-20260909T020000Z"
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
assert_contains "$FIXTURE/output" "latest run is not fully verified"
teardown_fixture

setup_fixture
make_verified_run "basebackup-20260926T020000Z"
write_last_success "basebackup-20260926T020000Z" 1790388000
bash "$BIN_DIR/monitor.sh" > "$FIXTURE/output"
assert_contains "$FIXTURE/output" "backup healthy"
export NEM_BACKUP_EPOCH=$((1790388000 + 129601))
run_fails bash "$BIN_DIR/monitor.sh"
assert_contains "$FIXTURE/output" "backup is stale"
teardown_fixture

setup_fixture
make_verified_run "basebackup-20260926T020000Z"
write_last_success "basebackup-20260926T020000Z" 1790388000
chmod 755 "$BACKUP_ROOT/.state"
run_fails bash "$BIN_DIR/monitor.sh"
[[ "$(stat -c '%a' "$BACKUP_ROOT/.state")" == "755" ]] || fail "monitor mutated unsafe state mode"
teardown_fixture

setup_fixture
make_verified_run "basebackup-20260926T020000Z"
mkdir -m 700 "$BACKUP_ROOT/.state"
printf '{"schema":1,"run_id":"basebackup-20260926T020000Z","status":"verified","epoch":1790388000,"extra":true}\n' > "$BACKUP_ROOT/.state/last-success.json"
chmod 600 "$BACKUP_ROOT/.state/last-success.json"
run_fails bash "$BIN_DIR/monitor.sh"
assert_contains "$FIXTURE/output" "last-success metadata is malformed"
teardown_fixture

setup_fixture
make_verified_run "basebackup-20260926T020000Z"
write_last_success "basebackup-20260926T020000Z" 1790388000
printf '{"schema":1,"run_id":"basebackup-20260926T030000Z","status":"failed","epoch":1790391600}\n' > "$BACKUP_ROOT/.state/last-failure.json"
chmod 600 "$BACKUP_ROOT/.state/last-failure.json"
run_fails bash "$BIN_DIR/monitor.sh"
assert_contains "$FIXTURE/output" "failure occurred at or after"
teardown_fixture

setup_fixture
make_verified_run "basebackup-20260926T020000Z"
write_last_success "basebackup-20260926T020000Z" 1790388000
export MOCK_AVAILABLE_BYTES=1
run_fails bash "$BIN_DIR/monitor.sh"
assert_contains "$FIXTURE/output" "insufficient capacity"
teardown_fixture

setup_fixture
write_config 7 129600 false
run_fails bash "$BIN_DIR/monitor.sh"
assert_contains "$FIXTURE/output" "automation is disabled"
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07; do make_verified_run "basebackup-202609${day}T020000Z"; done
write_last_success "basebackup-20260907T020000Z" "$NEM_BACKUP_EPOCH"
export MOCK_VERIFY_FAIL_CALL=2
run_fails bash "$BIN_DIR/backup.sh"
assert_contains "$BACKUP_ROOT/.state/last-success.json" '"run_id":"basebackup-20260907T020000Z"'
assert_contains "$BACKUP_ROOT/.state/last-failure.json" '"epoch":1790388000'
run_fails bash "$BIN_DIR/monitor.sh"
assert_contains "$FIXTURE/output" "failure occurred at or after"
unset MOCK_VERIFY_FAIL_CALL
export NEM_BACKUP_NOW=20260926T030000Z
export NEM_BACKUP_EPOCH=1790388001
bash "$BIN_DIR/backup.sh" > "$FIXTURE/output"
bash "$BIN_DIR/monitor.sh" > "$FIXTURE/output"
assert_contains "$FIXTURE/output" "backup healthy"
assert_not_exists "$BACKUP_ROOT/.state/last-failure.json"
teardown_fixture

printf 'retention and monitor tests passed\n'
