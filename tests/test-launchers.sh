#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/project"

cat > "$TMP/bin/sbx" <<'SBX'
#!/usr/bin/env bash
set -euo pipefail
: "${SBX_CAPTURE:?SBX_CAPTURE must be set}"
printf '%s\n' "$@" > "$SBX_CAPTURE"
SBX
chmod +x "$TMP/bin/sbx"

export PATH="$TMP/bin:$PATH"
export SBX_CAPTURE="$TMP/capture"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_line() {
  local line="$1" expected="$2"
  local actual
  actual="$(sed -n "${line}p" "$SBX_CAPTURE")"
  [ "$actual" = "$expected" ] || fail "line $line: expected '$expected', got '$actual'"
}

assert_contains() {
  local expected="$1"
  grep -Fx -- "$expected" "$SBX_CAPTURE" >/dev/null || fail "missing argument '$expected'"
}

run_launcher() {
  local launcher="$1"
  shift
  : > "$SBX_CAPTURE"
  (
    cd "$TMP/project"
    "$ROOT/bin/$launcher" "$@"
  )
}

run_launcher codex-here "fix the build"
assert_line 1 run
assert_line 2 --name
sed -n '3p' "$SBX_CAPTURE" | grep -Eq '^aiic-codex-project-[0-9]+$' || fail "unexpected Codex sandbox name"
assert_contains "image=ghcr.io/cainiaocome/ai-in-container:docker-sandbox"
assert_contains "$ROOT/sandbox/kits/codex"
assert_contains "$TMP/project"
assert_contains resume
assert_contains --last
assert_contains --yolo
assert_contains --search
assert_contains "fix the build"

run_launcher codex-here -n "new task"
if grep -Fx -- resume "$SBX_CAPTURE" >/dev/null; then
  fail "Codex -n must not resume the previous session"
fi
assert_contains --yolo
assert_contains --search
assert_contains "new task"

run_launcher claude-here
assert_contains "$ROOT/sandbox/kits/claude"
assert_contains --dangerously-skip-permissions
assert_contains --chrome
assert_contains -c

run_launcher claude-here --new
if grep -Fx -- -c "$SBX_CAPTURE" >/dev/null; then
  fail "Claude --new must not pass -c"
fi

run_launcher pi-here
assert_contains "$ROOT/sandbox/kits/pi"
assert_contains -c

run_launcher pi-here -n
if grep -Fx -- -c "$SBX_CAPTURE" >/dev/null; then
  fail "Pi -n must not pass -c"
fi

AGENT_HERE_IMAGE=example.invalid/custom:dev run_launcher codex-here -n
assert_contains "image=example.invalid/custom:dev"

echo "launcher tests: PASS"
