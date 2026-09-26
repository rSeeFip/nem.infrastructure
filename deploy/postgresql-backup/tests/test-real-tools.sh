#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/test-helper.sh
source "$TEST_DIR/test-helper.sh"
# shellcheck source=bin/common.sh
source "$BIN_DIR/common.sh"

setup_fixture
available="$(PATH="$ORIGINAL_PATH" available_bytes "$FIXTURE")"
[[ "$available" =~ ^[0-9]+$ ]] || fail "real df did not return numeric available bytes: $available"
mount_identity="$(PATH="$ORIGINAL_PATH" findmnt -n -o TARGET,MAJ:MIN -T "$FIXTURE")"
read -r mount_target mount_majmin <<< "$mount_identity"
[[ "$mount_target" == /* && "$mount_majmin" =~ ^[0-9]+:[0-9]+$ ]] || fail "real findmnt did not return target and filesystem identity: $mount_identity"
production_path="$(/usr/bin/env -i NEM_BACKUP_TESTING=0 PATH=/tmp /bin/bash -c "source \"\$1\"; printf '%s\\n' \"\$PATH\"" _ "$BIN_DIR/common.sh")"
[[ "$production_path" == "/usr/lib/postgresql/16/bin:/usr/sbin:/usr/bin:/sbin:/bin" ]] || fail "production PATH is not deterministic"
if /usr/bin/env -i NEM_BACKUP_TESTING=0 NEM_BACKUP_CONFIG=/tmp/unsafe /bin/bash -c "source \"\$1\"" _ "$BIN_DIR/common.sh" >"$FIXTURE/override.out" 2>&1; then
  fail "production accepted an unexpected NEM_BACKUP override"
fi
teardown_fixture

printf 'real tool tests passed\n'
