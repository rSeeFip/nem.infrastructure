#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/test-helper.sh
source "$TEST_DIR/test-helper.sh"

validate_fixture_root() {
  bash -c 'source "$1"; load_backup_config; validate_backup_root' _ "$BIN_DIR/common.sh"
}

setup_fixture
validate_fixture_root
teardown_fixture

setup_fixture
export MOCK_BACKUP_TARGET="$BACKUP_ROOT"
validate_fixture_root
teardown_fixture

setup_fixture
export MOCK_EXPECTED_TARGET=/
run_fails validate_fixture_root
teardown_fixture

setup_fixture
export MOCK_FINDMNT_MISSING_EXPECTED=1
run_fails validate_fixture_root
teardown_fixture

setup_fixture
export MOCK_BACKUP_TARGET=/
run_fails validate_fixture_root
teardown_fixture

setup_fixture
export MOCK_BACKUP_MAJMIN=8:2
run_fails validate_fixture_root
teardown_fixture

setup_fixture
export MOCK_EXPECTED_DEVICE=100
export MOCK_BACKUP_DEVICE=101
run_fails validate_fixture_root
teardown_fixture

printf 'mount guard tests passed\n'
