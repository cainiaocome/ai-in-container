# AI in Container

A Docker image based on Ubuntu 24.04 with the major terminal-first coding agents preinstalled, including GitHub Copilot CLI, Codex CLI, Claude Code, and Pi Coding Agent.

## Features

- **Ubuntu 24.04** base image
- **Timezone**: America/St_Johns (NST/NDT)
- **Homebrew** package manager
- **pyenv** for Python version management
- **Python 3.14.2** with performance optimizations
- **AI agents**: GitHub Copilot CLI, Codex CLI, Claude Code, Pi Coding Agent
- **Docker-in-Docker**: each agent container starts its own Docker daemon
- **Modern CLI tools**: ripgrep, bat, fd, fzf, uv, jq, tree, ShellCheck

## Quick Start

Use any launcher from `bin/`:

```bash
./bin/codex-here
./bin/claude-here
./bin/pi-here
```

Each launcher will:
- mount your current directory to `/app/{folder-name}` in the container
- persist agent state in `~/.homes_for_containers/copilot`
- reuse the same `ghcr.io/cainiaocome/ai-in-container:main` image
- run the container with `--privileged` so its internal Docker daemon can run
- start an isolated Docker daemon inside the agent container; the host Docker socket is not mounted
- run the agent command through interactive `bash` so env from the mapped `~/.bashrc` is available
- expose KVM, vhost-vsock, and TUN devices when available, including the required device groups and `NET_ADMIN` capability
- start the selected coding agent with the launcher's configured flags

Inside an agent session, Docker works normally:

```bash
docker info
docker run --rm hello-world
docker compose up -d
```

The nested Docker state is ephemeral by default. Because the outer agent container is started with `--rm`, its images, containers, volumes, and build cache disappear with the agent container.

## Launcher Behavior

- `codex-here` launches Codex CLI with `--yolo --search`
- `claude-here` launches Claude Code with `--dangerously-skip-permissions --chrome`
- `pi-here` launches Pi Coding Agent and resumes the latest session for the current project by default

By default the launchers resume the last session when the agent supports it. Pass `-n` or `--new` to start a fresh session instead. For `pi-here`, `-n` is intentionally reserved for starting a new session; rename a Pi session from inside Pi with `/name`.

## Prerequisites

- Docker installed and running locally
- A host that permits privileged containers
- Authentication for the agent you want to use, either through environment variables such as `GH_TOKEN`, `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY`, or via the persisted home directory

The launchers detect `/dev/kvm`, `/dev/vhost-vsock`, and `/dev/net/tun` individually. Missing devices disable only their corresponding VM acceleration or networking feature and do not prevent the agent container from starting.

## Building Locally

```bash
docker build -t ai-in-container .
```

## Image Tags

- `ghcr.io/cainiaocome/ai-in-container:main`
- `ghcr.io/cainiaocome/ai-in-container:{branch}`
