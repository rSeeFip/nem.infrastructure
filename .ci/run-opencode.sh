#!/usr/bin/env bash
set -euo pipefail

: "${OPENAI_API_KEY:?Set the OPENAI_API_KEY CI secret first.}"
: "${OPENCODE_PROMPT:?Provide a task in OPENCODE_PROMPT.}"
OPENCODE_MODEL="${OPENCODE_MODEL:-openai/gpt-6-astra}"

base_commit=$(git rev-parse HEAD)
results="$PWD/opencode-results"
runtime=$(mktemp -d "${TMPDIR:-/tmp}/opencode-ci.XXXXXX")
mkdir -p "$results"
printf '\n/opencode-results/\n' >> "$(git rev-parse --git-path info/exclude)"
printf '%s\n' "$base_commit" > "$results/base-commit.txt"

finish() {
  local status=$?
  trap - EXIT
  git add --intent-to-add -- . || status=1
  git diff --binary "$base_commit" -- . ':!opencode-results' > "$results/changes.patch" || status=1
  git status --short > "$results/worktree-status.txt" || status=1
  rm -rf -- "$runtime"
  exit "$status"
}
trap finish EXIT

export CI=true
export XDG_CONFIG_HOME="$runtime/config"
export XDG_DATA_HOME="$runtime/data"
export XDG_CACHE_HOME="$runtime/cache"
export XDG_STATE_HOME="$runtime/state"

npm exec --yes --package=@opencode/cli@2.1.4 -- \
  opencode run --standalone --auto --model "$OPENCODE_MODEL" \
  "Work in this checkout. Leave changes in the working tree for a patch artifact. Do not commit or push. Summarize your work and any checks performed.

Task:
$OPENCODE_PROMPT" 2>&1 | tee "$results/run.log"
