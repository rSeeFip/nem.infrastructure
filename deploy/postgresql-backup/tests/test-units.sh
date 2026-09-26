#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/test-helper.sh
source "$TEST_DIR/test-helper.sh"

backup_unit="$PROJECT_DIR/systemd/postgresql-backup.service"
monitor_unit="$PROJECT_DIR/systemd/postgresql-backup-monitor.service"

assert_contains "$backup_unit" "Environment=PATH=/usr/lib/postgresql/16/bin:/usr/sbin:/usr/bin:/sbin:/bin"
assert_contains "$backup_unit" "Environment=NEM_BACKUP_TESTING=0"
assert_contains "$backup_unit" "UnsetEnvironment=NEM_BACKUP_TEST_ROOT NEM_BACKUP_CONFIG NEM_BACKUP_NOW NEM_BACKUP_EPOCH"
assert_contains "$backup_unit" "TimeoutStartSec=6h"
assert_contains "$backup_unit" "TimeoutStopSec=5min"
assert_contains "$backup_unit" "KillMode=control-group"
assert_contains "$monitor_unit" "Environment=PATH=/usr/lib/postgresql/16/bin:/usr/sbin:/usr/bin:/sbin:/bin"
assert_contains "$monitor_unit" "Environment=NEM_BACKUP_TESTING=0"
assert_contains "$monitor_unit" "UnsetEnvironment=NEM_BACKUP_TEST_ROOT NEM_BACKUP_CONFIG NEM_BACKUP_NOW NEM_BACKUP_EPOCH"

printf 'unit tests passed\n'
