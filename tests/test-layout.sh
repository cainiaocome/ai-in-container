#!/usr/bin/env bash
# shellcheck disable=SC2016 # Literal ${...} and ${{...}} strings are intentional test fixtures.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# The experiment intentionally uses only Docker's generic sandbox runtime base.
grep -F 'FROM docker.io/docker/sandbox-templates:shell-docker' Dockerfile >/dev/null \
  || fail "Dockerfile must extend shell-docker"
if grep -E '^FROM .*:(codex|claude-code)(-docker)?([[:space:]]|$)' Dockerfile >/dev/null; then
  fail "Dockerfile must not inherit Docker agent-specific templates"
fi

# All coding agents must be installed by this repository's Dockerfile.
grep -F '"@openai/codex@${CODEX_VERSION}"' Dockerfile >/dev/null || fail "Codex install missing"
grep -F '"@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"' Dockerfile >/dev/null || fail "Claude Code install missing"
grep -F '"@earendil-works/pi-coding-agent@${PI_VERSION}"' Dockerfile >/dev/null || fail "Pi install missing"

for agent in codex claude pi; do
  spec="sandbox/kits/$agent/spec.yaml"
  [ -f "$spec" ] || fail "missing $spec"
  grep -F 'schemaVersion: "2"' "$spec" >/dev/null || fail "$spec must use schema v2"
  grep -F 'kind: sandbox' "$spec" >/dev/null || fail "$spec must be a sandbox kit"
  grep -F 'image: "${{ kit.args.image }}"' "$spec" >/dev/null || fail "$spec must use the image kit arg"
done

grep -F 'entrypoint: [codex]' sandbox/kits/codex/spec.yaml >/dev/null || fail "Codex entrypoint missing"
grep -F 'entrypoint: [claude]' sandbox/kits/claude/spec.yaml >/dev/null || fail "Claude entrypoint missing"
grep -F 'entrypoint: [pi]' sandbox/kits/pi/spec.yaml >/dev/null || fail "Pi entrypoint missing"

# Launchers must no longer run Docker containers directly.
if grep -R -E 'docker[[:space:]]+(run|rm|ps)' bin/ >/dev/null; then
  fail "launchers still invoke Docker container lifecycle commands"
fi

echo "layout tests: PASS"
