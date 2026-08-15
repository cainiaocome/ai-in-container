#!/usr/bin/env bash
set -euo pipefail

readonly AGENT_HERE_IMAGE_REPO="ghcr.io/cainiaocome/ai-in-container"
readonly AGENT_HERE_HOME_DIR_IN_CONTAINER="/home/ubuntu"

agent_here_init() {
  AGENT_HERE_SCRIPT_NAME="$(basename -- "$0")"
  AGENT_HERE_CONTAINER_NAME="${AGENT_HERE_CONTAINER_NAME:-$AGENT_HERE_SCRIPT_NAME}"
  AGENT_HERE_HOME_DIR_ON_HOST="${AGENT_HERE_HOME_DIR_ON_HOST:-$HOME/.homes_for_containers/copilot}"
  AGENT_HERE_IMAGE_TAG="main"
  AGENT_HERE_NEW_SESSION=0
  AGENT_HERE_ARGS=()

  for arg in "$@"; do
    case "$arg" in
    --dev)
      AGENT_HERE_IMAGE_TAG="dev"
      ;;
    -n | --new)
      AGENT_HERE_NEW_SESSION=1
      ;;
    *)
      AGENT_HERE_ARGS+=("$arg")
      ;;
    esac
  done

  AGENT_HERE_IMAGE="${AGENT_HERE_IMAGE_REPO}:${AGENT_HERE_IMAGE_TAG}"
  AGENT_HERE_SUBFOLDER_NAME="$(basename -- "$PWD")"
  AGENT_HERE_WORKDIR="/app/${AGENT_HERE_SUBFOLDER_NAME}"
}

agent_here_remove_existing_container() {
  if [ -n "$(docker ps -aq -f name=^/${AGENT_HERE_CONTAINER_NAME}$)" ]; then
    docker rm -f "${AGENT_HERE_CONTAINER_NAME}" >/dev/null
  fi
}

agent_here_build_docker_args() {
  local kvm_gid
  local vsock_gid

  mkdir -p "${AGENT_HERE_HOME_DIR_ON_HOST}"
  kvm_gid="$(stat -c '%g' /dev/kvm)"
  vsock_gid="$(stat -c '%g' /dev/vhost-vsock)"

  AGENT_HERE_DOCKER_ARGS=(
    --rm
    -it
    --name "${AGENT_HERE_CONTAINER_NAME}"
    --device=/dev/kvm
    --device=/dev/vhost-vsock
    --device=/dev/net/tun
    --group-add="${kvm_gid}"
    --group-add="${vsock_gid}"
    --cap-add=NET_ADMIN
    -v "${AGENT_HERE_HOME_DIR_ON_HOST}:${AGENT_HERE_HOME_DIR_IN_CONTAINER}"
    -v "${PWD}:${AGENT_HERE_WORKDIR}"
    -w "${AGENT_HERE_WORKDIR}"
  )
}

agent_here_run() {
  local -a command=("$@")
  local bash_command='exec "$@"'

  agent_here_remove_existing_container
  agent_here_build_docker_args

  docker run "${AGENT_HERE_DOCKER_ARGS[@]}" "${AGENT_HERE_IMAGE}" \
    bash -lic "${bash_command}" bash "${command[@]}"
}
