#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPA_IMAGE="${OPA_IMAGE:-openpolicyagent/opa:0.70.0-static}"
MATRIX="$ROOT_DIR/tests/opa/config_service_principal_matrix_test.rego"
PRODUCTION_POLICY="$ROOT_DIR/k8s/base/infrastructure/opa/policies/config.rego"
BUNDLE_POLICY="$ROOT_DIR/opa/bundles/nem/federation/services/config.rego"

run_matrix() {
    local label="$1"
    local policy="$2"
    local container="opa-config-matrix-$RANDOM-$RANDOM"
    local result

    docker create --name "$container" "$OPA_IMAGE" run --server --addr=:8181 >/dev/null
    docker cp "$policy" "$container:/tmp/config.rego"
    docker cp "$MATRIX" "$container:/tmp/config_service_principal_matrix_test.rego"
    docker start "$container" >/dev/null
    if ! result=$(docker exec "$container" /opa test /tmp/config.rego /tmp/config_service_principal_matrix_test.rego --format=json); then
        docker rm -f "$container" >/dev/null
        return 1
    fi
    docker rm -f "$container" >/dev/null
    python3 -c "import json, sys; results = json.load(sys.stdin); assert len(results) == 12, \"{} matrix cases executed; expected 12\".format(len(results)); print(\"{} matrix: {} passed\".format(sys.argv[1], len(results)))" "$label" <<<"$result"
}

run_matrix "production" "$PRODUCTION_POLICY"
run_matrix "bundle" "$BUNDLE_POLICY"
