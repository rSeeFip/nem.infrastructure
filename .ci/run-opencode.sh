#!/usr/bin/env bash
set -euo pipefail

: "${OPENCODE_PROMPT:?Provide a task in OPENCODE_PROMPT.}"
: "${OPENCODE_AUTH_PROFILE:?Set the persistent Codex authentication profile.}"
OPENCODE_MODEL="${OPENCODE_MODEL:-openai/gpt-6-astra}"
umask 077
unset OPENAI_API_KEY

base_commit=$(git rev-parse HEAD)
results="$PWD/opencode-results"
runtime=$(mktemp -d "${TMPDIR:-/tmp}/opencode-ci.XXXXXX")
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

exclude=$(git rev-parse --git-path info/exclude)
mkdir -p "$results" "$(dirname "$exclude")"
printf '\n/opencode-results/\n' >> "$exclude"
printf '%s\n' "$base_commit" > "$results/base-commit.txt"

export CI=true
export XDG_CONFIG_HOME="$runtime/config"
auth_home="$HOME/.local/share/opencode-ci/$OPENCODE_AUTH_PROFILE"
mkdir -p "$auth_home"
chmod 700 "$auth_home"
export XDG_DATA_HOME="$auth_home/data"
export XDG_CACHE_HOME="$auth_home/cache"
export XDG_STATE_HOME="$runtime/state"
export npm_config_cache="$auth_home/npm-cache"

if ! command -v npm >/dev/null || ! command -v node >/dev/null ||
  ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 24 ? 0 : 1)'; then
  case "$(uname -sm)" in
    'Linux x86_64')
      arch=x64
      checksum=eb6728e77c576a35162c122c45ccadf224d89ff00abc8dae46cc2897c6002d7c
      ;;
    'Linux aarch64')
      arch=arm64
      checksum=33c37be234ba8bee041961047b19160f4d7d0f164e8e246f78bdd10feff148b3
      ;;
    *)
      printf '%s\n' 'Install Node.js 24 or newer on this runner.' >&2
      exit 1
      ;;
  esac
  archive="node-v24.22.1-linux-$arch.tar.gz"
  curl --fail --location --retry 3 --silent --show-error \
    "https://nodejs.org/dist/v24.22.1/$archive" --output "$runtime/$archive"
  printf '%s  %s\n' "$checksum" "$runtime/$archive" | sha256sum --check
  mkdir -p "$runtime/node"
  tar -xzf "$runtime/$archive" --strip-components=1 -C "$runtime/node"
  export PATH="$runtime/node/bin:$PATH"
fi

opencode=(npm exec --yes --package=@opencode/cli@2.1.4 -- opencode)
accounts=$("${opencode[@]}" auth list --standalone --format json)
if ! printf '%s' "$accounts" | node -e '
  const accounts = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
  const connected = accounts.some(account => account.id === "openai" &&
    account.connections.some(connection => connection.type === "credential" && connection.method === "oauth"));
  process.exit(connected ? 0 : 1);
'; then
  printf '%s\n' 'Authorize this runner using the Codex device URL and code shown below.'
  "${opencode[@]}" auth login openai --method chatgpt-headless --standalone
fi

"${opencode[@]}" run --standalone --auto --model "$OPENCODE_MODEL" \
  "Work in this checkout. Leave changes in the working tree for a patch artifact. Do not commit or push. Summarize your work and any checks performed.

Task:
$OPENCODE_PROMPT" 2>&1 | tee "$results/run.log"
