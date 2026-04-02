#!/usr/bin/env bash

# validate-structure.sh - Verify Kustomize base+overlay separation is clean and platform-agnostic
# 5 tests: base platform-agnostic, kustomization validity, overlay refs base,
# overlay contains only patches, and shows future overlay template.

set -euo pipefail

# Enable recursive globbing
shopt -s globstar

# Detect directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
BASE_DIR="${REPO_ROOT}/nem.infrastructure/k8s/base"
OVERLAY_DIR="${REPO_ROOT}/nem.infrastructure/k8s/overlays/wsl2-k3s"

# Color output
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\033[0m'
  BOLD=$'\033[1m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
else
  RESET=""
  BOLD=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
fi

# Counters
TOTAL_ISSUES=0
FIX_MODE=false

# Logging
log_section() {
  printf '\n%s== %s ==%s\n' "$BOLD$BLUE" "$1" "$RESET"
}

log_info() {
  printf '  %s[INFO]%s %s\n' "$CYAN" "$RESET" "$1"
}

log_pass() {
  printf '  %s[CLEAN]%s %s\n' "$GREEN$BOLD" "$RESET" "$1"
}

log_issue() {
  printf '  %s[ISSUE]%s %s:%s — %s\n' "$RED$BOLD" "$RESET" "$1" "$2" "$3"
  ((TOTAL_ISSUES++)) || true
}

log_warn() {
  printf '  %s[WARN]%s %s\n' "$YELLOW$BOLD" "$RESET" "$1"
}

usage() {
  printf 'Usage: %s [OPTIONS]\n' "${0##*/}"
  printf '\nOptions:\n'
  printf '  --fix       Suggest fixes (currently suggest-only mode)\n'
  printf '  --verbose   Show all files checked\n'
  printf '  --help      Show this help\n'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix) FIX_MODE=true ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ============================================================================
# TEST 1: Base directory has no platform-specific config
# ============================================================================
log_section "TEST 1: Base Platform-Agnostic Check"

if [[ ! -d "$BASE_DIR" ]]; then
  log_warn "Base directory not found: $BASE_DIR"
else
  log_info "Scanning $BASE_DIR for platform-specific patterns..."

  forbidden_patterns=(
    "192\.168\."
    "wsl"
    "WSL"
    "k3s"
    "K3S"
    "mirrored"
    "windows"
    "Windows"
    "host\.docker\.internal"
    "nem\.local"
  )

  found_issues=0
  
  # Create pattern regex for single grep pass
  pattern_regex="(192\.168\.|wsl|WSL|k3s|K3S|mirrored|windows|Windows|host\.docker\.internal|nem\.local)"
  
  # Single grep pass through all YAML files
  while IFS=: read -r file line_num line; do
    trimmed="${line#[[:space:]]}"
    # Skip comments
    if [[ "$trimmed" =~ ^# ]]; then
      continue
    fi
    # Allow specific LiteLLM external IP everywhere
    if [[ "$line" =~ 192\.168\.8\.75 ]]; then
      continue
    fi
    log_issue "${file#$BASE_DIR/}" "$line_num" "Platform-specific pattern found: ${line:0:80}"
    ((found_issues++)) || true || true
  done < <(find "$BASE_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) -exec grep -Hn "$pattern_regex" {} \; 2>/dev/null | grep -v "^[^:]*:[^:]*:#" || true)

  if [[ $found_issues -eq 0 ]]; then
    log_pass "No platform-specific patterns found in base/"
  else
    log_warn "Found $found_issues platform-specific pattern(s)"
  fi
fi

# ============================================================================
# TEST 2: All base kustomization.yaml files are valid
# ============================================================================
log_section "TEST 2: Kustomization Validity Check"

if [[ ! -d "$BASE_DIR" ]]; then
  log_warn "Base directory not found for kustomization check"
else
  log_info "Validating all kustomization.yaml files in base..."

  found_issues=0
  while IFS= read -r kustom_file; do
    if ! grep -q "^apiVersion:" "$kustom_file"; then
      log_issue "${kustom_file#$REPO_ROOT/}" "1" "Missing 'apiVersion' field"
      ((found_issues++)) || true
    fi
    if ! grep -q "^kind: Kustomization" "$kustom_file"; then
      log_issue "${kustom_file#$REPO_ROOT/}" "1" "Missing 'kind: Kustomization'"
      ((found_issues++)) || true
    fi
  done < <(find "$BASE_DIR" -name "kustomization.yaml" | sort)

  if [[ $found_issues -eq 0 ]]; then
    log_pass "All kustomization.yaml files are valid"
  else
    log_warn "Found $found_issues kustomization issue(s)"
  fi
fi

# ============================================================================
# TEST 3: Overlay correctly references base
# ============================================================================
log_section "TEST 3: Overlay Referencing Base Check"

overlay_kustom="$OVERLAY_DIR/kustomization.yaml"

if [[ ! -f "$overlay_kustom" ]]; then
  log_warn "Overlay kustomization.yaml not found: $overlay_kustom"
else
  log_info "Checking overlay references to base..."

  if grep -q "bases:" "$overlay_kustom" || grep -q "^  - .*base" "$overlay_kustom"; then
    log_pass "Overlay has reference to base"
  else
    log_issue "${overlay_kustom#$REPO_ROOT/}" "1" "No 'bases' or base reference found"
  fi

  if [[ -f "$BASE_DIR/kustomization.yaml" ]]; then
    base_resources=$(grep "^  - " "$BASE_DIR/kustomization.yaml" | sed 's/^[[:space:]]*-[[:space:]]*//' | sort)
    overlay_resources=$(grep "^  - " "$overlay_kustom" | sed 's/^[[:space:]]*-[[:space:]]*//' | sort)
    overlap=$(comm -12 <(echo "$base_resources") <(echo "$overlay_resources") | grep -v "base" || true)
    if [[ -n "$overlap" ]]; then
      log_warn "Overlay redefines base resources (should use patches)"
    else
      log_pass "No resource duplication between base and overlay"
    fi
  fi
fi

# ============================================================================
# TEST 4: Overlay contains ONLY platform-specific patches
# ============================================================================
log_section "TEST 4: Overlay Content Check"

if [[ ! -d "$OVERLAY_DIR" ]]; then
  log_warn "Overlay directory not found: $OVERLAY_DIR"
else
  log_info "Checking overlay directory structure..."

  allowed_dirs=("kustomization.yaml" "patches" "scripts" "ingress" "config")
  found_issues=0

  for item in "$OVERLAY_DIR"/*; do
    item_basename=$(basename "$item")
    is_allowed=false

    for allowed in "${allowed_dirs[@]}"; do
      if [[ "$item_basename" == "$allowed" ]]; then
        is_allowed=true
        break
      fi
    done

    if [[ "$is_allowed" == false ]] && [[ "$item_basename" != ".gitkeep" ]]; then
      log_issue "${item#$REPO_ROOT/}" "1" "Unexpected item in overlay"
      ((found_issues++)) || true
    fi
  done

  if [[ -d "$OVERLAY_DIR/patches" ]]; then
    for patch_file in "$OVERLAY_DIR"/patches/*.yaml "$OVERLAY_DIR"/patches/*.yml; do
      [[ -f "$patch_file" ]] || continue
      if grep -qE "^kind: (Deployment|Service|ConfigMap)" "$patch_file" 2>/dev/null; then
        if grep -q "^  name:" "$patch_file" 2>/dev/null && grep -q "^spec:" "$patch_file" 2>/dev/null; then
          log_warn "Patch appears to be full manifest: $(basename "$patch_file")"
          ((found_issues++)) || true
        fi
      fi
    done
  fi

  if [[ $found_issues -eq 0 ]]; then
    log_pass "Overlay contains only platform-specific files"
  else
    log_warn "Found $found_issues overlay content issue(s)"
  fi
fi



# ============================================================================
# TEST 5: Future overlay template (informational)
# ============================================================================
log_section "TEST 5: Future Overlay Template (Example)"

log_info "To create a new overlay (e.g., docker-desktop), follow this structure:"
printf '%s\n' "$BOLD"
printf 'nem.infrastructure/k8s/overlays/docker-desktop/\n'
printf '  kustomization.yaml (references ../../base)\n'
printf '  patches/\n'
printf '    docker-resources.yaml (resource limits)\n'
printf '  config/\n'
printf '    storage-class.yaml\n'
printf '    registries.yaml\n'
printf '  scripts/\n'
printf '    setup-docker-desktop.sh\n'
printf '\n'
printf 'Key principle:\n'
printf '  - Base = deployment-agnostic manifests\n'
printf '  - Overlay = docker-desktop-specific patches/config\n'
printf '  - Result: kubectl kustomize build overlays/docker-desktop/\n'
printf '%s\n' "$RESET"

log_info "Base can be reused with different overlays via strategic merge patches"

# ============================================================================
# Summary
# ============================================================================
log_section "SUMMARY"

if [[ $TOTAL_ISSUES -eq 0 ]]; then
  printf '%s✓ All validation tests passed%s\n' "$GREEN$BOLD" "$RESET"
  exit 0
else
  printf '%s✗ Found %d issue(s)%s\n' "$RED$BOLD" "$TOTAL_ISSUES" "$RESET"
  exit 1
fi
