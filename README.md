# AI in Container

A Docker image based on Ubuntu 24.04 with the major terminal-first coding agents preinstalled, including GitHub Copilot CLI, Codex CLI, and Claude Code.

## Features

- **Ubuntu 24.04** base image
- **Timezone**: America/St_Johns (NST/NDT)
- **Homebrew** package manager
- **pyenv** for Python version management
- **Python 3.14.2** with performance optimizations
- **AI agents**: GitHub Copilot CLI, Codex CLI, Claude Code
- **Modern CLI tools**: ripgrep, bat, fd, fzf, uv, jq, tree, ShellCheck

## Quick Start

Use any launcher from `bin/`:

```bash
./bin/ai-here
./bin/copilot-here
./bin/codex-here
./bin/claude-here
```

Each launcher will:
- mount your current directory to `/app/{folder-name}` in the container
- persist agent state in `~/.homes_for_containers/copilot`
- reuse the same container image, with an optional `--dev` tag switch
- run the agent command through interactive `bash` so env from the mapped `~/.bashrc` is available
- expose KVM, vhost-vsock, and TUN devices, add their device groups, and grant `NET_ADMIN` for VM networking
- start the selected coding agent with permissive flags enabled

## Launcher Behavior

- `ai-here` launches GitHub Copilot CLI
- `copilot-here` is a symlink to `ai-here`
- `codex-here` launches Codex CLI with `--yolo --search`
- `claude-here` launches Claude Code with `--dangerously-skip-permissions --chrome`

By default the launchers resume the last session when the agent supports it. Pass `-n` or `--new` to start a fresh session instead. Pass `--dev` to use `ghcr.io/cainiaocome/ai-in-container:dev`.

## Prerequisites

- Docker installed and running locally
- `/dev/kvm`, `/dev/vhost-vsock`, and `/dev/net/tun` available on the local Docker daemon host
- Authentication for the agent you want to use, either through environment variables such as `GH_TOKEN`, `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY`, or via the persisted home directory

## Building Locally

```bash
docker build -t ai-in-container .
```

## Image Tags

- `ghcr.io/cainiaocome/ai-in-container:main`
- `ghcr.io/cainiaocome/ai-in-container:dev`
- `ghcr.io/cainiaocome/ai-in-container:{branch}`
