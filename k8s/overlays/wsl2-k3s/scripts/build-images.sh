#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-localhost:5000}"
TAG="${TAG:-dev}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$(dirname "$0")/../../../../.." && pwd)}"
DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"

readonly REGISTRY TAG WORKSPACE_ROOT DOCKER_BUILDKIT
readonly TOTAL_IMAGES=13

built_count=0
declare -a built_images=()

on_error() {
  local exit_code="$1"
  local line_no="$2"
  echo ""
  echo "ERROR: build-images.sh failed at line ${line_no} (exit code: ${exit_code})" >&2
  exit "$exit_code"
}

trap 'on_error $? $LINENO' ERR

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $command_name" >&2
    exit 1
  fi
}

require_path() {
  local path="$1"
  local description="$2"

  if [ ! -e "$path" ]; then
    echo "ERROR: Missing ${description}: $path" >&2
    exit 1
  fi
}

check_registry() {
  local registry_url="$REGISTRY"

  if [[ "$registry_url" != http://* && "$registry_url" != https://* ]]; then
    registry_url="http://$registry_url"
  fi

  registry_url="${registry_url%/}/v2/"

  local status_code
  status_code="$(curl -sS -o /dev/null -w "%{http_code}" "$registry_url")"

  if [ "$status_code" != "200" ] && [ "$status_code" != "401" ]; then
    echo "ERROR: Registry check failed for $registry_url (HTTP $status_code)" >&2
    exit 1
  fi
}

build_and_push() {
  local name="$1"
  local context="$2"
  local dockerfile="$3"
  local target="${4:-}"

  require_path "$context" "build context"
  require_path "$dockerfile" "Dockerfile"

  echo ""
  echo "=========================================="
  echo "Building: $name"
  echo "Context:  $context"
  echo "Dockerfile: $dockerfile"
  if [ -n "$target" ]; then
    echo "Target: $target"
  fi
  echo "Image: $REGISTRY/$name:$TAG"
  echo "=========================================="

  local -a docker_build_args=(build -t "$REGISTRY/$name:$TAG" -f "$dockerfile")

  if [ -n "$target" ]; then
    docker_build_args+=(--target "$target")
  fi

  docker_build_args+=("$context")

  echo "=== Building $name ==="
  docker "${docker_build_args[@]}"
  echo "=== Pushing $name ==="
  docker push "$REGISTRY/$name:$TAG"
  echo "=== Done: $name ==="
  echo "✓ $name built and pushed successfully"

  built_count=$((built_count + 1))
  built_images+=("$name")
}

pull_tag_and_push() {
  local name="$1"
  local source_image="$2"

  echo ""
  echo "=========================================="
  echo "Using fallback image for: $name"
  echo "Source image: $source_image"
  echo "Target image: $REGISTRY/$name:$TAG"
  echo "=========================================="

  echo "=== Pulling fallback image for $name ==="
  docker pull "$source_image"
  echo "=== Tagging $name ==="
  docker tag "$source_image" "$REGISTRY/$name:$TAG"
  echo "=== Pushing $name ==="
  docker push "$REGISTRY/$name:$TAG"
  echo "=== Done: $name ==="
  echo "✓ $name tagged and pushed successfully"

  built_count=$((built_count + 1))
  built_images+=("$name")
}

echo "=========================================="
echo "nem.* image build and push"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Workspace root: $WORKSPACE_ROOT"
echo "BuildKit: $DOCKER_BUILDKIT"
echo "=========================================="

require_command docker
require_command curl

echo "Checking Docker daemon..."
docker info >/dev/null

echo "Checking local registry..."
check_registry

export DOCKER_BUILDKIT

MCP_DOCKERFILE="$WORKSPACE_ROOT/nem.MCP/Dockerfile"
MCP_UI_DOCKERFILE="$WORKSPACE_ROOT/nem.MCP/packages/web-app/Dockerfile"
KNOWHUB_DOCKERFILE="$WORKSPACE_ROOT/nem.KnowHub/Dockerfile"
MIMIR_DOCKERFILE="$WORKSPACE_ROOT/nem.Mimir/docker/api/Dockerfile"
CLASSIFICATION_DOCKERFILE="$WORKSPACE_ROOT/nem.Classification/Dockerfile"
COMMS_DOCKERFILE="$WORKSPACE_ROOT/nem.Comms/Dockerfile"
BACKUP_DOCKERFILE="$WORKSPACE_ROOT/nem.Backup/Dockerfile"
SCHEDULER_DOCKERFILE="$WORKSPACE_ROOT/nem.Scheduler/Dockerfile"
MEDIAHUB_DOCKERFILE="$WORKSPACE_ROOT/nem.MediaHub/Dockerfile"
WEB_DOCKERFILE="$WORKSPACE_ROOT/nem.Web/Dockerfile"
HOMEASSISTANT_DOCKERFILE="$WORKSPACE_ROOT/nem.HomeAssistant/Dockerfile"
GATEWAY_DOCKERFILE="$WORKSPACE_ROOT/infrastructure/nem.Gateway/Dockerfile"
PRESIDIO_DOCKERFILE="$WORKSPACE_ROOT/nem.Classification/sidecar/presidio/Dockerfile"

build_and_push "nem-mcp" "$WORKSPACE_ROOT" "$MCP_DOCKERFILE" "api"

if [ -f "$MCP_UI_DOCKERFILE" ]; then
  build_and_push "nem-mcp-ui" "$WORKSPACE_ROOT/nem.MCP" "$MCP_UI_DOCKERFILE"
else
  echo "INFO: $MCP_UI_DOCKERFILE not found; using $MCP_DOCKERFILE target ui instead."
  build_and_push "nem-mcp-ui" "$WORKSPACE_ROOT" "$MCP_DOCKERFILE" "ui"
fi

build_and_push "nem-knowhub" "$WORKSPACE_ROOT" "$KNOWHUB_DOCKERFILE" "api"
build_and_push "nem-mimir" "$WORKSPACE_ROOT/nem.Mimir" "$MIMIR_DOCKERFILE"
build_and_push "nem-classification" "$WORKSPACE_ROOT/nem.Classification" "$CLASSIFICATION_DOCKERFILE"
build_and_push "nem-comms" "$WORKSPACE_ROOT/nem.Comms" "$COMMS_DOCKERFILE"
build_and_push "nem-backup" "$WORKSPACE_ROOT" "$BACKUP_DOCKERFILE"
build_and_push "nem-scheduler" "$WORKSPACE_ROOT/nem.Scheduler" "$SCHEDULER_DOCKERFILE"
build_and_push "nem-mediahub" "$WORKSPACE_ROOT" "$MEDIAHUB_DOCKERFILE"
build_and_push "nem-web" "$WORKSPACE_ROOT/nem.Web" "$WEB_DOCKERFILE"
build_and_push "nem-homeassistant" "$WORKSPACE_ROOT" "$HOMEASSISTANT_DOCKERFILE"
build_and_push "nem-gateway" "$WORKSPACE_ROOT/infrastructure" "$GATEWAY_DOCKERFILE"

if [ -f "$PRESIDIO_DOCKERFILE" ]; then
  build_and_push "nem-presidio" "$WORKSPACE_ROOT/nem.Classification/sidecar/presidio" "$PRESIDIO_DOCKERFILE"
else
  echo "INFO: $PRESIDIO_DOCKERFILE not found; using public Presidio image fallback."
  pull_tag_and_push "nem-presidio" "mcr.microsoft.com/presidio-analyzer:latest"
fi

echo ""
echo "=========================================="
echo "Built and pushed $built_count/$TOTAL_IMAGES images"
printf 'Images: %s\n' "${built_images[*]}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "=========================================="
