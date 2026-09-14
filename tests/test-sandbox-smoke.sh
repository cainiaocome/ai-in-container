#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
IMAGE="${AGENT_HERE_IMAGE:-ghcr.io/cainiaocome/ai-in-container:docker-sandbox}"
NAME="aiic-smoke-$RANDOM-$$"

cleanup() {
  sbx rm --force "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v sbx >/dev/null 2>&1 || {
  echo "sbx is required for this integration test" >&2
  exit 127
}

# Create instead of `run` so the smoke test does not attach to an interactive agent.
sbx create \
  --name "$NAME" \
  --kit-arg "image=$IMAGE" \
  "$ROOT/sandbox/kits/pi" \
  "$ROOT"

sbx exec "$NAME" bash -lc '
  set -euo pipefail
  command -v codex
  command -v claude
  command -v pi
  codex --version
  claude --version
  pi --version
  docker version
  docker info >/dev/null
  docker run --rm alpine:3.22 sh -c "echo nested-docker-ok"
'

echo "Docker Sandbox smoke test: PASS"
