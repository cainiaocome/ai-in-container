#!/usr/bin/env bash
# shellcheck disable=SC2034 # State variables are consumed by the launcher that sources this file.
set -euo pipefail

readonly AGENT_HERE_IMAGE_DEFAULT="ghcr.io/cainiaocome/ai-in-container:docker-sandbox"

agent_here_path_is_within() {
  local path="$1"
  local root="$2"

  if [ "$root" = "/" ]; then
    return 0
  fi

  [[ "$path" = "$root" || "$path" = "$root/"* ]]
}

agent_here_init() {
  local agent="$1"
  local project_root
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
  AGENT_HERE_REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
  AGENT_HERE_KIT_DIR="${AGENT_HERE_REPO_ROOT}/sandbox/kits/${AGENT_HERE_AGENT}"
  AGENT_HERE_IMAGE="${AGENT_HERE_IMAGE:-$AGENT_HERE_IMAGE_DEFAULT}"

  # Preserve the original launcher model: one stable runtime identity per agent,
  # independent of the project currently being worked on.
  AGENT_HERE_SANDBOX_NAME="${AGENT_HERE_SANDBOX_NAME:-${AGENT_HERE_AGENT}-here}"

  # Docker Sandbox workspace mounts are fixed when a VM is created. To let one
  # agent VM work across projects, mount a stable parent directory once and use
  # `sbx exec --workdir` to enter the current project on every invocation.
  #
  # An explicit root is preferred. Without one, choose the parent of the current
  # Git repository (or the parent of PWD outside Git), which commonly covers a
  # directory containing sibling projects without exposing the whole home dir.
  if [ -n "${AGENT_HERE_WORKSPACE_ROOT:-}" ]; then
    if [ ! -d "$AGENT_HERE_WORKSPACE_ROOT" ]; then
      echo "AGENT_HERE_WORKSPACE_ROOT does not exist: $AGENT_HERE_WORKSPACE_ROOT" >&2
      return 2
    fi
    AGENT_HERE_WORKSPACE_ROOT="$(cd -- "$AGENT_HERE_WORKSPACE_ROOT" && pwd -P)"
  elif project_root="$(git -C "$AGENT_HERE_PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    project_root="$(cd -- "$project_root" && pwd -P)"
    AGENT_HERE_WORKSPACE_ROOT="$(dirname -- "$project_root")"
  else
    AGENT_HERE_WORKSPACE_ROOT="$(dirname -- "$AGENT_HERE_PROJECT_DIR")"
  fi

  if ! agent_here_path_is_within "$AGENT_HERE_PROJECT_DIR" "$AGENT_HERE_WORKSPACE_ROOT"; then
    cat >&2 <<EOF
Current project is outside AGENT_HERE_WORKSPACE_ROOT.
  project: $AGENT_HERE_PROJECT_DIR
  root:    $AGENT_HERE_WORKSPACE_ROOT
Choose a root that contains this project and recreate $AGENT_HERE_SANDBOX_NAME if its workspace was created with a different root.
EOF
    return 2
  fi
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

agent_here_sandbox_exists() {
  local sandboxes
  sandboxes="$(sbx ls -q)"
  grep -Fxq -- "$AGENT_HERE_SANDBOX_NAME" <<<"$sandboxes"
}

agent_here_create_sandbox() {
  sbx create \
    --name "$AGENT_HERE_SANDBOX_NAME" \
    --kit-arg "image=$AGENT_HERE_IMAGE" \
    "$AGENT_HERE_KIT_DIR" \
    "$AGENT_HERE_WORKSPACE_ROOT"
}

agent_here_require_project_visible() {
  if sbx exec "$AGENT_HERE_SANDBOX_NAME" test -d "$AGENT_HERE_PROJECT_DIR"; then
    return 0
  fi

  cat >&2 <<EOF
$AGENT_HERE_SANDBOX_NAME already exists, but this project is not visible inside it:
  $AGENT_HERE_PROJECT_DIR

Docker Sandbox workspace mounts are fixed at VM creation time. Remove and recreate
this agent VM with a workspace root that contains all projects you want it to use:

  sbx rm $AGENT_HERE_SANDBOX_NAME
  AGENT_HERE_WORKSPACE_ROOT=/path/to/projects <agent>-here
EOF
  return 2
}

agent_here_run() {
  local -a command=("$@")

  agent_here_require_sbx

  if ! agent_here_sandbox_exists; then
    agent_here_create_sandbox
  fi

  agent_here_require_project_visible

  sbx exec -it \
    --workdir "$AGENT_HERE_PROJECT_DIR" \
    "$AGENT_HERE_SANDBOX_NAME" \
    "$AGENT_HERE_AGENT" \
    "${command[@]}"
}
