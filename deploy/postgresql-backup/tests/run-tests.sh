#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$TEST_DIR"/mocks/*
bash "$TEST_DIR/test-backup.sh"
bash "$TEST_DIR/test-retention-monitor.sh"
bash "$TEST_DIR/test-lock.sh"
bash "$TEST_DIR/test-mount.sh"
bash "$TEST_DIR/test-real-tools.sh"
bash "$TEST_DIR/test-units.sh"
printf 'all PostgreSQL backup tests passed\n'
