#!/usr/bin/env bash
set -euo pipefail

# Usage: install-python.sh [versions...]
# Example: install-python.sh 3.14.2 3.13.7

VERSIONS=("${@:-3.14.2}")
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init -)"

for version in "${VERSIONS[@]}"; do
  echo "Installing Python ${version}..."
  PYTHON_CONFIGURE_OPTS="${PYTHON_CONFIGURE_OPTS:-}" \
    CFLAGS="${CFLAGS:-}" \
    LDFLAGS="${LDFLAGS:-}" \
    pyenv install -s "${version}"
done

pyenv global "${VERSIONS[0]}"
