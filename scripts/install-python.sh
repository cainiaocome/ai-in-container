#!/usr/bin/env bash
set -euo pipefail

# Usage: install-python.sh [versions...]
# Example: install-python.sh 3.14.2 3.13.7

VERSIONS="${*:-3.14.2}"

# If running as root, run installer as ubuntu user so pyenv is set up in their home
if [ "$(id -u)" -eq 0 ]; then
  su - ubuntu -c "bash -lc 'export PYENV_ROOT=\"${PYENV_ROOT:-/home/ubuntu/.pyenv}\" && export PATH=\"/home/linuxbrew/.linuxbrew/bin:\$PYENV_ROOT/bin:\$PYENV_ROOT/shims:\$PATH\" && eval "'"'"$(pyenv init -)"'"'" && for v in ${VERSIONS}; do echo "Installing Python $v..."; PYTHON_CONFIGURE_OPTS=\"${PYTHON_CONFIGURE_OPTS}\" CFLAGS=\"${CFLAGS}\" LDFLAGS=\"${LDFLAGS}\" pyenv install -v "$v" || pyenv install -f "$v"; done; pyenv global ${VERSIONS%% *}'"
else
  export PYENV_ROOT="${PYENV_ROOT:-/home/ubuntu/.pyenv}"
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
  eval "$(pyenv init -)"
  for v in ${VERSIONS}; do
    echo "Installing Python $v..."
    PYTHON_CONFIGURE_OPTS="${PYTHON_CONFIGURE_OPTS}" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" pyenv install -v "$v" || pyenv install -f "$v"
  done
  pyenv global ${VERSIONS%% *}
fi
