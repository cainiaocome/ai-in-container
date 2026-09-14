#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/project" "$TMP/project2" "$TMP/state"

cat > "$TMP/bin/sbx" <<'SBX'
#!/usr/bin/env bash
set -euo pipefail
: "${SBX_CAPTURE:?SBX_CAPTURE must be set}"
: "${SBX_STATE_DIR:?SBX_STATE_DIR must be set}"

command="$1"
shift

printf '__CALL__ %s\n' "$command" >> "$SBX_CAPTURE"
printf '%s\n' "$@" >> "$SBX_CAPTURE"
printf '__END__\n' >> "$SBX_CAPTURE"

case "$command" in
ls)
  if [ "${1:-}" = "-q" ]; then
    for state in "$SBX_STATE_DIR"/*; do
      [ -e "$state" ] || continue
      basename -- "$state"
    done
  fi
  ;;
create)
  name=""
  args=("$@")
  for ((i = 0; i < ${#args[@]}; i++)); do
    if [ "${args[$i]}" = "--name" ]; then
      name="${args[$((i + 1))]}"
      break
    fi
  done
  [ -n "$name" ] || {
    echo "mock sbx create: --name missing" >&2
    exit 2
  }
  workspace="${args[$((${#args[@]} - 1))]}"
  printf '%s\n' "$workspace" > "$SBX_STATE_DIR/$name"
  ;;
exec)
  # The launcher probes project visibility as:
  #   sbx exec NAME test -d PATH
  if [ "${2:-}" = "test" ] && [ "${3:-}" = "-d" ]; then
    name="$1"
    path="${4:-}"
    [ -f "$SBX_STATE_DIR/$name" ] || exit 1
    root="$(cat "$SBX_STATE_DIR/$name")"
    if [ "$root" = "/" ] || [ "$path" = "$root" ] || [[ "$path" = "$root/"* ]]; then
      exit 0
    fi
    exit 1
  fi
  ;;
esac
SBX
chmod +x "$TMP/bin/sbx"

export PATH="$TMP/bin:$PATH"
export SBX_CAPTURE="$TMP/capture"
export SBX_STATE_DIR="$TMP/state"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  grep -Fx -- "$expected" "$SBX_CAPTURE" >/dev/null || fail "missing argument '$expected'"
}

assert_no_call() {
  local call="$1"
  if grep -Fx -- "__CALL__ $call" "$SBX_CAPTURE" >/dev/null; then
    fail "unexpected sbx $call call"
  fi
}

run_launcher_in() {
  local dir="$1"
  local launcher="$2"
  shift 2
  : > "$SBX_CAPTURE"
  (
    cd "$dir"
    "$ROOT/bin/$launcher" "$@"
  )
}

run_launcher() {
  local launcher="$1"
  shift
  run_launcher_in "$TMP/project" "$launcher" "$@"
}

# First Codex invocation creates exactly one Codex VM. Because the fixture is
# not a Git repo, the safe automatic workspace root is the project's parent.
run_launcher codex-here "fix the build"
assert_contains "__CALL__ create"
assert_contains --name
assert_contains codex-here
assert_contains "image=ghcr.io/cainiaocome/ai-in-container:docker-sandbox"
assert_contains "$ROOT/sandbox/kits/codex"
assert_contains "$TMP"
assert_contains "__CALL__ exec"
assert_contains --workdir
assert_contains "$TMP/project"
assert_contains codex
assert_contains resume
assert_contains --last
assert_contains --yolo
assert_contains --search
assert_contains "fix the build"

# Re-running Codex reuses the same VM instead of creating one per project.
run_launcher codex-here -n "new task"
assert_no_call create
if grep -Fx -- resume "$SBX_CAPTURE" >/dev/null; then
  fail "Codex -n must not resume the previous session"
fi
assert_contains codex-here
assert_contains "$TMP/project"
assert_contains --yolo
assert_contains --search
assert_contains "new task"

# A sibling project still uses codex-here because both live under the fixed
# workspace root chosen when the VM was created.
run_launcher_in "$TMP/project2" codex-here -n "sibling task"
assert_no_call create
assert_contains codex-here
assert_contains "$TMP/project2"
assert_contains "sibling task"

run_launcher claude-here
assert_contains "__CALL__ create"
assert_contains claude-here
assert_contains "$ROOT/sandbox/kits/claude"
assert_contains claude
assert_contains --dangerously-skip-permissions
assert_contains --chrome
assert_contains -c

run_launcher claude-here --new
assert_no_call create
if grep -Fx -- -c "$SBX_CAPTURE" >/dev/null; then
  fail "Claude --new must not pass -c"
fi

run_launcher pi-here
assert_contains "__CALL__ create"
assert_contains pi-here
assert_contains "$ROOT/sandbox/kits/pi"
assert_contains pi
assert_contains -c

run_launcher pi-here -n
assert_no_call create
if grep -Fx -- -c "$SBX_CAPTURE" >/dev/null; then
  fail "Pi -n must not pass -c"
fi

# Image overrides apply when a VM is created. Use a distinct name so this call
# exercises creation rather than the already-existing Codex VM.
export AGENT_HERE_IMAGE=example.invalid/custom:dev
export AGENT_HERE_SANDBOX_NAME=codex-custom
run_launcher codex-here -n
assert_contains "__CALL__ create"
assert_contains codex-custom
assert_contains "image=example.invalid/custom:dev"
unset AGENT_HERE_IMAGE AGENT_HERE_SANDBOX_NAME

echo "launcher tests: PASS"
