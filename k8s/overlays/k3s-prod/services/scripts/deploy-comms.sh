#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." && pwd)"
WORKSPACE_ROOT="$(cd -- "${INFRA_ROOT}/.." && pwd)"
COMMS_DIR=""
SOURCE_REF=""
DRY_RUN=false

NAMESPACE=nem-apps
DEPLOYMENT=nem-comms
CONTAINER=nem-comms
SERVICE=nem-comms
EXTERNAL_SECRET=nem-comms-configuration-secret
ROLLOUT_TIMEOUT="${NEM_DEPLOY_ROLLOUT_TIMEOUT:-5m}"
HEALTH_TIMEOUT_SECONDS="${NEM_DEPLOY_HEALTH_TIMEOUT_SECONDS:-60}"
OPERATOR_PATH="${NEM_COMMS_OPERATOR_PATH:-/api/v1/operator/inbox}"
LOCAL_PORT="${NEM_COMMS_LOCAL_PORT:-15280}"
KUBECTL=(sudo k3s kubectl)
PATCH_FILE="${INFRA_ROOT}/k8s/overlays/k3s-prod/services/comms/runtime-env-patch.yaml"
LOCK_FILE="${INFRA_ROOT}/k8s/overlays/k3s-prod/services/comms/build-inputs.lock"
EXTERNAL_SECRET_FILE="${INFRA_ROOT}/k8s/overlays/k3s-prod/services/comms/external-secret.yaml"
PVC_FILE="${INFRA_ROOT}/k8s/overlays/k3s-prod/services/comms/data-protection-pvc.yaml"
SERVICE_FILE="${INFRA_ROOT}/k8s/overlays/k3s-prod/services/comms/service.yaml"
IMAGE_ARCHIVE=""
PREVIOUS_IMAGE=""
ROLLBACK_ARMED=false
PORT_FORWARD_PID=""
declare -A LOCK_SHAS=()

usage() {
  cat <<'EOF'
Usage: deploy-comms.sh [--workspace-root PATH] [--comms-dir PATH] [--source-ref REF] [--dry-run]

Build and deploy the immutable Comms image pinned in runtime-env-patch.yaml.
EOF
}

log() { printf '%s\n' "$*" >&2; }
cleanup() {
  if [[ -n "$PORT_FORWARD_PID" ]]; then
    kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
    wait "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$IMAGE_ARCHIVE" ]] && ! "$DRY_RUN"; then
    sudo rm -f -- "$IMAGE_ARCHIVE" || log "WARNING: Could not remove image archive ${IMAGE_ARCHIVE}"
  fi
}
rollback() {
  local status="$1" rollback_status=0
  "$ROLLBACK_ARMED" || return "$status"
  log "Deployment failed after patch; restoring ${DEPLOYMENT} to ${PREVIOUS_IMAGE}."
  run "${KUBECTL[@]}" set image "deployment/${DEPLOYMENT}" "${CONTAINER}=${PREVIOUS_IMAGE}" --namespace "$NAMESPACE" || rollback_status=$?
  run "${KUBECTL[@]}" rollout status "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" || rollback_status=$?
  if ! "$DRY_RUN" && ! rewrite_manifest_image "$PREVIOUS_IMAGE"; then
    log "ERROR: Failed to restore the checked-out manifest pin."
    rollback_status=1
  fi
  (( rollback_status == 0 )) || log "ERROR: Rollback did not complete; manual intervention is required."
  return "$status"
}
fail() {
  log "ERROR: $*"
  if "$ROLLBACK_ARMED"; then
    trap - ERR
    rollback 1 || exit 1
  fi
  exit 1
}
on_error() {
  local status="$1" line="$2"
  trap - ERR
  log "ERROR: deploy-comms.sh failed at line ${line} (exit ${status})."
  rollback "$status" || exit "$status"
  exit "$status"
}
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
require_directory() { [[ -d "$1" ]] || fail "Missing $2: $1"; }
run() {
  printf '+ '; printf '%q ' "$@"; printf '\n'
  "$DRY_RUN" || "$@"
}
rewrite_manifest_image() {
  local image="$1" temporary
  temporary="$(mktemp "${PATCH_FILE}.XXXXXX")"
  chmod --reference="$PATCH_FILE" "$temporary"
  awk -v image="$image" '$1 == "image:" { if (seen++) exit 1; print "          image: " image; next } { print } END { if (seen != 1) exit 1 }' "$PATCH_FILE" >"$temporary" || { rm -f "$temporary"; return 1; }
  mv "$temporary" "$PATCH_FILE"
}
load_lock() {
  local line repo sha
  [[ -f "$LOCK_FILE" ]] || fail "Missing build input lock: ${LOCK_FILE}"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^(nem\.(Contracts|Plugins\.Sdk|Configuration))=([0-9a-f]{40})$ ]] || fail "Invalid build input lock line"
    repo="${BASH_REMATCH[1]}"
    sha="${BASH_REMATCH[3]}"
    [[ -z "${LOCK_SHAS[$repo]:-}" ]] || fail "Duplicate build input lock entry: ${repo}"
    LOCK_SHAS["$repo"]="$sha"
  done <"$LOCK_FILE"
  for repo in nem.Contracts nem.Plugins.Sdk nem.Configuration; do
    [[ -n "${LOCK_SHAS[$repo]:-}" ]] || fail "Missing build input lock entry: ${repo}"
  done
  (( ${#LOCK_SHAS[@]} == 3 )) || fail "Unexpected build input lock entry"
}
validate_siblings() {
  local repo head
  for repo in nem.Contracts nem.Plugins.Sdk nem.Configuration; do
    require_directory "${WORKSPACE_ROOT}/${repo}" "required build sibling ${repo}"
    head="$(GIT_MASTER=1 git -C "${WORKSPACE_ROOT}/${repo}" rev-parse HEAD)" || fail "Cannot resolve ${repo} HEAD"
    [[ "$head" == "${LOCK_SHAS[$repo]}" ]] || fail "${repo} HEAD ${head} does not match locked ${LOCK_SHAS[$repo]}"
    log "Validated build sibling ${repo} at ${head}"
  done
}
validate_comms_source() {
  local head source_sha
  if [[ -n "$SOURCE_REF" ]]; then
    source_sha="$(GIT_MASTER=1 git -C "$COMMS_DIR" rev-parse --verify "${SOURCE_REF}^{commit}")" || fail "Cannot resolve Comms source ref: ${SOURCE_REF}"
    [[ "$source_sha" == "${TAG}"* ]] || fail "Comms source ref does not match pinned tag ${TAG}"
    if "$DRY_RUN"; then
      head="$(GIT_MASTER=1 git -C "$COMMS_DIR" rev-parse HEAD)" || fail "Cannot resolve Comms HEAD"
      [[ "$head" == "$source_sha" ]] || fail "--dry-run does not checkout --source-ref; current Comms HEAD must already equal ${source_sha}"
    else
      GIT_MASTER=1 git -C "$COMMS_DIR" checkout --detach "$source_sha"
    fi
  fi
  COMMS_SHA="$(GIT_MASTER=1 git -C "$COMMS_DIR" rev-parse HEAD)" || fail "Cannot resolve Comms HEAD"
  [[ "$COMMS_SHA" == "${TAG}"* ]] || fail "Pinned tag ${TAG} does not match Comms HEAD ${COMMS_SHA}"
  if "$DRY_RUN"; then
    if GIT_MASTER=1 git -C "$COMMS_DIR" rev-parse --verify origin/main >/dev/null 2>&1; then
      GIT_MASTER=1 git -C "$COMMS_DIR" merge-base --is-ancestor HEAD origin/main || fail "Comms HEAD is not an ancestor of origin/main"
    fi
  else
    GIT_MASTER=1 git -C "$COMMS_DIR" fetch --no-tags origin main
    GIT_MASTER=1 git -C "$COMMS_DIR" merge-base --is-ancestor HEAD origin/main || fail "Comms HEAD is not an ancestor of origin/main"
  fi
}
remove_target_images() {
  local image images
  if "$DRY_RUN"; then
    log "+ sudo k3s ctr images ls -q"
    log "+ sudo k3s ctr images rm docker.io/library/nem.comms:${TAG} # if present"
    log "+ sudo k3s ctr images rm ${TARGET_IMAGE} # if present"
    return
  fi
  images="$(sudo k3s ctr images ls -q)"
  for image in "docker.io/library/nem.comms:${TAG}" "$TARGET_IMAGE"; do
    if grep -Fxq "$image" <<<"$images"; then
      sudo k3s ctr images rm "$image"
    fi
  done
}

trap 'on_error $? $LINENO' ERR
trap cleanup EXIT
while (( $# > 0 )); do
  case "$1" in
    --workspace-root|--comms-dir|--source-ref)
      (( $# >= 2 )) || fail "$1 requires a value"
      case "$1" in
        --workspace-root) WORKSPACE_ROOT="$2" ;;
        --comms-dir) COMMS_DIR="$2" ;;
        --source-ref) SOURCE_REF="$2" ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

WORKSPACE_ROOT="$(cd -- "$WORKSPACE_ROOT" && pwd)"
COMMS_DIR="${COMMS_DIR:-${WORKSPACE_ROOT}/nem.Comms}"
require_directory "$COMMS_DIR" "nem.Comms checkout"
[[ -f "$PATCH_FILE" && -f "${COMMS_DIR}/Dockerfile" ]] || fail "Missing Comms deployment input"
[[ "$LOCAL_PORT" =~ ^[1-9][0-9]{3,4}$ ]] && (( LOCAL_PORT <= 65535 )) || fail "NEM_COMMS_LOCAL_PORT must be 1000-65535"
MANIFEST_IMAGE="$(awk '$1 == "image:" { print $2; count++ } END { if (count != 1) exit 1 }' "$PATCH_FILE")" || fail "Expected exactly one image field in ${PATCH_FILE}"
[[ "$MANIFEST_IMAGE" =~ ^localhost/nem\.comms:([0-9a-f]{7,40})$ ]] || fail "Comms image must be localhost/nem.comms:<7-40 lowercase hex SHA>"
TAG="${BASH_REMATCH[1]}"
TARGET_IMAGE="localhost/nem.comms:${TAG}"
IMAGE_ARCHIVE="/tmp/nem-comms-${USER:-runner}-${RANDOM}.tar"
load_lock
require_command git
validate_comms_source
validate_siblings

if "$DRY_RUN"; then
  log "Dry run: no checkout, build, import, cleanup, or cluster mutation will occur."
  log "Pinned image: ${TARGET_IMAGE}"
  run sudo buildah bud --no-cache --network=host --platform linux/arm64 -t "$TARGET_IMAGE" -f "${COMMS_DIR}/Dockerfile" "$WORKSPACE_ROOT"
  run sudo rm -f "$IMAGE_ARCHIVE"
  run sudo buildah push "$TARGET_IMAGE" "docker-archive:${IMAGE_ARCHIVE}:${TARGET_IMAGE}"
  remove_target_images
  run sudo k3s ctr images import "$IMAGE_ARCHIVE"
  run "${KUBECTL[@]}" apply --filename "$EXTERNAL_SECRET_FILE"
  run "${KUBECTL[@]}" apply --filename "$PVC_FILE"
  run "${KUBECTL[@]}" apply --filename "$SERVICE_FILE"
  run "${KUBECTL[@]}" wait --namespace "$NAMESPACE" --for=condition=Ready "externalsecret/${EXTERNAL_SECRET}" --timeout="$ROLLOUT_TIMEOUT"
  run "${KUBECTL[@]}" patch "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" --type strategic --patch-file "$PATCH_FILE"
  run "${KUBECTL[@]}" rollout status "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"
  run "${KUBECTL[@]}" port-forward --namespace "$NAMESPACE" "service/${SERVICE}" "${LOCAL_PORT}:5280"
  run curl --fail --silent --show-error --max-time 2 "http://127.0.0.1:${LOCAL_PORT}/health"
  run curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 5 "http://127.0.0.1:${LOCAL_PORT}${OPERATOR_PATH}"
  exit 0
fi

[[ "$(uname -m)" == aarch64 ]] || fail "ARM64 production deployment requires uname -m to be aarch64"
for command_name in buildah curl sudo k3s; do require_command "$command_name"; done
sudo -n true || fail "Passwordless sudo is required for production deployment"
PREVIOUS_IMAGE="$("${KUBECTL[@]}" get "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="nem-comms")].image}')"
[[ -n "$PREVIOUS_IMAGE" ]] || fail "Could not capture current Comms image"
PREVIOUS_RESTARTS="$("${KUBECTL[@]}" get pods --namespace "$NAMESPACE" -l app=nem-comms -o jsonpath='{range .items[*].status.containerStatuses[*]}{.restartCount}{"\n"}{end}' | awk '{ sum += $1 } END { print sum + 0 }')"

run sudo buildah bud --no-cache --network=host --platform linux/arm64 -t "$TARGET_IMAGE" -f "${COMMS_DIR}/Dockerfile" "$WORKSPACE_ROOT"
run sudo rm -f "$IMAGE_ARCHIVE"
run sudo buildah push "$TARGET_IMAGE" "docker-archive:${IMAGE_ARCHIVE}:${TARGET_IMAGE}"
remove_target_images
run sudo k3s ctr images import "$IMAGE_ARCHIVE"
run "${KUBECTL[@]}" apply --filename "$EXTERNAL_SECRET_FILE"
run "${KUBECTL[@]}" apply --filename "$PVC_FILE"
run "${KUBECTL[@]}" apply --filename "$SERVICE_FILE"
run "${KUBECTL[@]}" wait --namespace "$NAMESPACE" --for=condition=Ready "externalsecret/${EXTERNAL_SECRET}" --timeout="$ROLLOUT_TIMEOUT"
ROLLBACK_ARMED=true
run "${KUBECTL[@]}" patch "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" --type strategic --patch-file "$PATCH_FILE"
[[ "${NEM_DEPLOY_INJECT_FAILURE:-}" != after-patch ]] || fail "Injected failure after patch"
run "${KUBECTL[@]}" rollout status "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"
ACTUAL_IMAGE="$("${KUBECTL[@]}" get "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="nem-comms")].image}')"
[[ "$ACTUAL_IMAGE" == "$TARGET_IMAGE" ]] || fail "Deployment image differs from pin"
READY="$("${KUBECTL[@]}" get "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')"
UPDATED="$("${KUBECTL[@]}" get "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" -o jsonpath='{.status.updatedReplicas}')"
AVAILABLE="$("${KUBECTL[@]}" get "deployment/${DEPLOYMENT}" --namespace "$NAMESPACE" -o jsonpath='{.status.availableReplicas}')"
[[ "$READY" == 1 && "$UPDATED" == 1 && "$AVAILABLE" == 1 ]] || fail "Expected 1 ready, updated, and available replica"
CURRENT_RESTARTS="$("${KUBECTL[@]}" get pods --namespace "$NAMESPACE" -l app=nem-comms -o jsonpath='{range .items[*].status.containerStatuses[*]}{.restartCount}{"\n"}{end}' | awk '{ sum += $1 } END { print sum + 0 }')"
(( CURRENT_RESTARTS <= PREVIOUS_RESTARTS )) || fail "Container restarts increased from ${PREVIOUS_RESTARTS} to ${CURRENT_RESTARTS}"
"${KUBECTL[@]}" port-forward --namespace "$NAMESPACE" "service/${SERVICE}" "${LOCAL_PORT}:5280" >/tmp/nem-comms-port-forward.log 2>&1 &
PORT_FORWARD_PID="$!"
for (( attempt = 1; attempt <= HEALTH_TIMEOUT_SECONDS; attempt++ )); do
  curl --fail --silent --show-error --max-time 2 "http://127.0.0.1:${LOCAL_PORT}/health" >/dev/null && break
  (( attempt < HEALTH_TIMEOUT_SECONDS )) || fail "Comms health endpoint did not return HTTP 200"
  sleep 1
done
OPERATOR_STATUS="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 5 "http://127.0.0.1:${LOCAL_PORT}${OPERATOR_PATH}")"
[[ "$OPERATOR_STATUS" == 401 ]] || fail "Protected operator endpoint returned HTTP ${OPERATOR_STATUS}, expected 401"
ROLLBACK_ARMED=false
log "Comms deployment succeeded: ${TARGET_IMAGE}"
