#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR/bundles/nem"
DATA_DIR="$BUNDLE_DIR/data"

echo "=== NEM OPA Policy Test Runner ==="
echo "Bundle: $BUNDLE_DIR"

# Copy dev data overlay as the active data for testing
if [ -f "$DATA_DIR/dev.json" ]; then
  cp "$DATA_DIR/dev.json" "$BUNDLE_DIR/data.json"
  echo "Using dev data overlay for tests"
fi

# Determine OPA binary
if command -v opa &>/dev/null; then
  OPA_CMD="opa"
elif command -v docker &>/dev/null; then
  OPA_CMD="docker"
else
  echo "ERROR: Neither 'opa' nor 'docker' found. Install one to run tests." >&2
  exit 1
fi

# Run tests
echo "Running OPA tests..."
if command -v opa &>/dev/null; then
  opa test "$BUNDLE_DIR" -v 2>&1
else
  docker run --rm \
    -v "$BUNDLE_DIR:/bundle" \
    -w /bundle \
    openpolicyagent/opa:0.68.0 \
    test /bundle -v 2>&1
fi

echo "=== Tests complete ==="
