# AI in Container

A Docker image based on Ubuntu 24.04 with the major terminal-first coding agents preinstalled, including GitHub Copilot CLI, Codex CLI, Claude Code, and Pi Coding Agent.

## Features

- **Ubuntu 24.04** base image
- **Timezone**: America/St_Johns (NST/NDT)
- **Homebrew** package manager
- **Python 3** from Ubuntu packages, with built-in `venv` support
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

## Python Virtual Environments

Create and activate a project-local environment with the system Python:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

The image uses Ubuntu's system Python. `venv` isolates project packages but does not install or switch Python versions.

## Launcher Behavior

- `codex-here` launches Codex CLI with `--yolo --search`
- `claude-here` launches Claude Code with `--dangerously-skip-permissions --chrome`
- `pi-here` launches Pi Coding Agent and resumes the latest session for the current project by default

By default the launchers resume the last session when the agent supports it. Pass `-n` or `--new` to start a fresh session instead. For `pi-here`, `-n` is intentionally reserved for starting a new session; rename a Pi session from inside Pi with `/name`.

### Additional Docker Arguments

All three launchers accept `ADDITIONAL_DOCKER_ARGUMENTS` as trusted caller configuration containing Docker options and their values. Use one literal Docker argument per line: an option and its value occupy separate lines unless using Docker's `--option=value` form. Spaces within a line are preserved, empty lines are ignored, and an unset or empty variable adds nothing. Arguments cannot contain embedded newlines. Shell quotes and expressions are passed literally; they are not interpreted or expanded by the launcher.

```bash
ADDITIONAL_DOCKER_ARGUMENTS="--env
EXAMPLE_MESSAGE=hello world" pi-here
```

These arguments are appended after the default and device options, before the image name. Supply only Docker options and their values, not an image name or container command. Duplicate or conflicting options follow Docker's behavior; do not rely on them to override launcher defaults.

### Review an Original Repository

In a `review-here` wrapper, capture the original directory before changing directories, create the review workspace and output directory, and mount the original repository read-only instead of copying it with `rsync`:

```bash
CURRENT_DIR="$(pwd -P)"
PROJECT_NAME="$(basename "$CURRENT_DIR")"
REVIEW_DIR="$HOME/pi-reviews/$PROJECT_NAME"

mkdir -p "$REVIEW_DIR/$PROJECT_NAME" "$REVIEW_DIR/review-output"
# Generate agents.md in REVIEW_DIR as before.
cd "$REVIEW_DIR"

ADDITIONAL_DOCKER_ARGUMENTS="--mount
type=bind,source=$CURRENT_DIR,target=/app/$PROJECT_NAME/$PROJECT_NAME,readonly" \
  pi-here
```

The existing workspace mount stays writable, while the nested project mount reads the original repository without duplicating it. Host edits are visible during review. Commands that write into the project must redirect their output elsewhere, such as `review-output`. Docker's mount syntax has its own escaping rules for unusual paths, including paths containing commas.

Existing copies under the review workspace require deliberate cleanup; mounting over them does not reclaim their disk space.

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
