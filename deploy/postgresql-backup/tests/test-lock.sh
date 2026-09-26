#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/test-helper.sh
source "$TEST_DIR/test-helper.sh"

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
mkdir -m 700 "$BACKUP_ROOT/.state"
exec 8<"$BACKUP_ROOT/.state"
flock -n 8 || fail "could not establish competing state lock"
exec 9<"$BACKUP_ROOT/.state"
run_fails bash "$BIN_DIR/retention.sh"
assert_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
assert_contains "$FIXTURE/output" "another backup or retention operation is active"
flock -u 8
exec 8<&-
exec 9<&-
teardown_fixture

setup_fixture
for day in 01 02 03 04 05 06 07 08; do make_verified_run "basebackup-202609${day}T020000Z"; done
mkdir -m 700 "$BACKUP_ROOT/.state"
exec 9<"$BACKUP_ROOT/.state"
flock -n 9 || fail "could not establish inherited state lock"
bash "$BIN_DIR/retention.sh"
assert_not_exists "$BACKUP_ROOT/basebackup-20260901T020000Z"
flock -u 9
exec 9<&-
teardown_fixture

printf 'lock tests passed\n'
