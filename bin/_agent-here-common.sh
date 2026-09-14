#!/usr/bin/env bash
# shellcheck disable=SC2034 # State variables are consumed by the launcher that sources this file.
set -euo pipefail

readonly AGENT_HERE_IMAGE_DEFAULT="ghcr.io/cainiaocome/ai-in-container:docker-sandbox"

agent_here_init() {
  local agent="$1"
  shift

  AGENT_HERE_AGENT="${agent}"
  AGENT_HERE_NEW_SESSION=0
  AGENT_HERE_ARGS=()

  for arg in "$@"; do
    case "$arg" in
    -n | --new)
      AGENT_HERE_NEW_SESSION=1
      ;;
    *)
      AGENT_HERE_ARGS+=("$arg")
      ;;
    esac
  done

  AGENT_HERE_PROJECT_DIR="$(pwd -P)"
  AGENT_HERE_PROJECT_NAME="$(basename -- "$AGENT_HERE_PROJECT_DIR")"
  AGENT_HERE_REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
  AGENT_HERE_KIT_DIR="${AGENT_HERE_REPO_ROOT}/sandbox/kits/${AGENT_HERE_AGENT}"
  AGENT_HERE_IMAGE="${AGENT_HERE_IMAGE:-$AGENT_HERE_IMAGE_DEFAULT}"

  local project_slug project_id default_name
  project_slug="$(printf '%s' "$AGENT_HERE_PROJECT_NAME" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '-' \
    | sed 's/^-//; s/-$//' \
    | cut -c1-24)"
  [ -n "$project_slug" ] || project_slug="project"
  project_id="$(printf '%s' "$AGENT_HERE_PROJECT_DIR" | cksum | awk '{print $1}')"
  default_name="aiic-${AGENT_HERE_AGENT}-${project_slug}-${project_id}"
  AGENT_HERE_SANDBOX_NAME="${AGENT_HERE_SANDBOX_NAME:-$default_name}"
}

agent_here_require_sbx() {
  if ! command -v sbx >/dev/null 2>&1; then
    cat >&2 <<'MSG'
Docker Sandboxes CLI (sbx) is required.
Install it from https://docs.docker.com/ai/sandboxes/install/ and run `sbx login` once.
MSG
    return 127
  fi
}

agent_here_run() {
  local -a command=("$@")

  agent_here_require_sbx

  sbx run \
    --name "$AGENT_HERE_SANDBOX_NAME" \
    --kit-arg "image=$AGENT_HERE_IMAGE" \
    "$AGENT_HERE_KIT_DIR" \
    "$AGENT_HERE_PROJECT_DIR" \
    -- "${command[@]}"
}
