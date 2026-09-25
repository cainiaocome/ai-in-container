#!/usr/bin/env bash
set -euo pipefail

readonly AGENT_HERE_IMAGE="ghcr.io/cainiaocome/ai-in-container:main"
readonly AGENT_HERE_HOME_DIR_IN_CONTAINER="/home/ubuntu"

agent_here_init() {
  AGENT_HERE_SCRIPT_NAME="$(basename -- "$0")"
  AGENT_HERE_CONTAINER_NAME="${AGENT_HERE_CONTAINER_NAME:-$AGENT_HERE_SCRIPT_NAME}"
  AGENT_HERE_HOME_DIR_ON_HOST="${AGENT_HERE_HOME_DIR_ON_HOST:-$HOME/.homes_for_containers/copilot}"
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

  AGENT_HERE_SUBFOLDER_NAME="$(basename -- "$PWD")"
  AGENT_HERE_WORKDIR="/app/${AGENT_HERE_SUBFOLDER_NAME}"
}

agent_here_remove_existing_container() {
  if [ -n "$(docker ps -aq -f name=^/${AGENT_HERE_CONTAINER_NAME}$)" ]; then
    docker rm -f "${AGENT_HERE_CONTAINER_NAME}" >/dev/null
  fi
}

agent_here_build_docker_args() {
  mkdir -p "${AGENT_HERE_HOME_DIR_ON_HOST}"

  AGENT_HERE_DOCKER_ARGS=(
    --rm
    -it
    --privileged
    --name "${AGENT_HERE_CONTAINER_NAME}"
    -v "${AGENT_HERE_HOME_DIR_ON_HOST}:${AGENT_HERE_HOME_DIR_IN_CONTAINER}"
    -v "${PWD}:${AGENT_HERE_WORKDIR}"
    -v /var/lib/docker
    -w "${AGENT_HERE_WORKDIR}"
  )

  if [ -e /dev/kvm ]; then
    AGENT_HERE_DOCKER_ARGS+=(
      --device=/dev/kvm
      --group-add="$(stat -c '%g' /dev/kvm)"
    )
  fi

  if [ -e /dev/vhost-vsock ]; then
    AGENT_HERE_DOCKER_ARGS+=(
      --device=/dev/vhost-vsock
      --group-add="$(stat -c '%g' /dev/vhost-vsock)"
    )
  fi

  if [ -e /dev/net/tun ]; then
    AGENT_HERE_DOCKER_ARGS+=(
      --device=/dev/net/tun
      --cap-add=NET_ADMIN
    )
  fi
}

agent_here_run() {
  local -a command=("$@")
  local bash_command='exec "$@"'

  agent_here_remove_existing_container
  agent_here_build_docker_args

  docker run "${AGENT_HERE_DOCKER_ARGS[@]}" "${AGENT_HERE_IMAGE}" \
    bash -lic "${bash_command}" bash "${command[@]}"
}
