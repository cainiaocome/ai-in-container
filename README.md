# AI in Container — Docker Sandbox experiment

This branch replaces the launcher runtime from a normal Docker container with
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). Each project/agent
gets an isolated microVM with its own filesystem, Linux kernel, and Docker
daemon, so coding agents can use `docker build`, `docker run`, and
`docker compose` normally without Docker-in-Docker or access to the host Docker
socket.

## Important design choice

The project **does not use Docker's Codex or Claude Code agent images**.

`Dockerfile` starts only from the generic
`docker/sandbox-templates:shell-docker` runtime because Docker Sandboxes needs
its `agent` user, VM integration, and in-VM Docker Engine. The coding agents are
then installed by this repository itself:

- `@openai/codex`
- `@anthropic-ai/claude-code`
- `@earendil-works/pi-coding-agent`

The three sandbox kits under `sandbox/kits/` only select which binary is the
entrypoint. Agent versions therefore come from this repository's Docker build,
not from Docker's agent-specific templates.

## Architecture

```text
host project directory
        │
        │ direct workspace mount
        ▼
Docker Sandbox microVM
├── self-built ai-in-container template
│   ├── Codex CLI
│   ├── Claude Code
│   ├── Pi Coding Agent
│   └── development tools
├── private dockerd
│   ├── docker build
│   ├── docker run
│   └── docker compose
└── persistent VM filesystem
```

The agent can control Docker inside its own microVM. It does **not** receive the
host's `/var/run/docker.sock`.

## Prerequisites

- Docker Sandboxes (`sbx`) 0.42.0 or newer
- `sbx login` completed once on the host
- Linux: Ubuntu 24.04+ with KVM available and the user in the `kvm` group
- macOS: Apple silicon on macOS Sonoma 14+
- Access to `ghcr.io/cainiaocome/ai-in-container:docker-sandbox`

For a private GHCR package, store registry credentials once:

```bash
gh auth token | sbx secret set --registry ghcr.io --password-stdin
```

## Quick start

From any project directory, run one of the launchers from this repository:

```bash
/path/to/ai-in-container/bin/codex-here
/path/to/ai-in-container/bin/claude-here
/path/to/ai-in-container/bin/pi-here
```

The default behavior preserves the existing launcher semantics:

- `codex-here` resumes the last Codex session with `--yolo --search`
- `claude-here` resumes Claude Code with `--dangerously-skip-permissions --chrome`
- `pi-here` resumes the most recent Pi session
- `-n` / `--new` starts a new agent session

Any remaining arguments are forwarded to the selected agent.

```bash
/path/to/ai-in-container/bin/codex-here -n "fix the failing tests"
```

## Sandbox lifecycle and persistence

The launcher derives a stable sandbox name from:

```text
agent + project directory name + checksum of absolute project path
```

That means the same project and agent reconnect to the same sandbox on future
runs. Installed packages, agent state, Docker images, Docker build cache, and
other VM files persist across stop/start cycles.

The workspace itself is directly mounted from the host and remains the source
of truth for project files.

List sandboxes:

```bash
sbx ls
```

Stop one without deleting its state:

```bash
sbx stop <sandbox-name>
```

Delete it completely when a clean VM is desired:

```bash
sbx rm <sandbox-name>
```

Override the automatically generated name when needed:

```bash
AGENT_HERE_SANDBOX_NAME=my-test-vm /path/to/bin/codex-here
```

## Image selection

This branch defaults to:

```text
ghcr.io/cainiaocome/ai-in-container:docker-sandbox
```

Override it without editing a kit:

```bash
AGENT_HERE_IMAGE=ghcr.io/example/ai-in-container:dev \
  /path/to/bin/codex-here
```

All three kits use the same image. The image contains all agents.

## Building locally

```bash
make build
```

or:

```bash
docker build -t ghcr.io/cainiaocome/ai-in-container:docker-sandbox .
```

The agent versions are Docker build arguments and default to `latest`:

```bash
docker build \
  --build-arg CODEX_VERSION=0.150.0 \
  --build-arg CLAUDE_CODE_VERSION=2.1.270 \
  --build-arg PI_VERSION=latest \
  -t my-ai-sandbox:dev .
```

Docker Sandboxes uses a separate template image store from the normal host
Docker daemon. To test a locally built image without pushing it to a registry:

```bash
make load-template IMAGE=my-ai-sandbox:dev
AGENT_HERE_IMAGE=my-ai-sandbox:dev ./bin/codex-here
```

## Authentication

Because this branch deliberately uses self-installed agents instead of Docker's
built-in Codex/Claude integrations, authentication is owned by each agent.

For subscription logins, authenticate from inside the agent as normal:

- Codex: sign in with ChatGPT when Codex prompts
- Claude Code: use `/login`
- Pi: use `/login` and choose the provider

The sandbox filesystem persists, so the login survives sandbox stop/start.
Deleting the sandbox deletes credentials stored inside that VM.

This differs from Docker's built-in agent kits, which can use Docker's
host-side credential proxy. A future version can add explicit v2 kit credential
declarations if host-side secret isolation is desired while still keeping the
agent binaries self-installed.

## Docker inside the agent VM

No DinD setup is required. `shell-docker` supplies a full Docker Engine inside
the microVM. From Codex, Claude Code, Pi, or an `sbx exec` shell:

```bash
docker version
docker info
docker build .
docker compose up -d
```

The in-VM Docker daemon is isolated from the host daemon.

## Tests

Fast tests do not require Docker Sandboxes or KVM:

```bash
make test
```

They verify:

- launcher argument forwarding and resume/new-session behavior
- stable `sbx` invocation and custom image override
- all three kits point at the same self-built image
- the Dockerfile uses only `shell-docker`, never Docker's Codex/Claude templates
- Codex, Claude Code, and Pi are explicitly installed in our Dockerfile
- launchers no longer invoke `docker run` / `docker rm` for their lifecycle

Validate the kit schema with an installed `sbx` CLI:

```bash
make validate-kits
```

Run the real microVM integration smoke test on a compatible host:

```bash
make test-sandbox
```

The smoke test creates a temporary Docker Sandbox, checks that all three agent
binaries exist, checks `docker version` and `docker info`, then runs:

```bash
docker run --rm alpine:3.22 sh -c 'echo nested-docker-ok'
```

inside the microVM and removes the temporary sandbox afterward.

GitHub Actions runs ShellCheck plus the fast tests. The KVM smoke test is kept
out of GitHub-hosted runners because Docker Sandboxes requires hardware/nested
virtualization and an authenticated `sbx` environment; it can be wired to a
KVM-enabled self-hosted runner later.

## Repository layout

```text
.
├── Dockerfile
├── Makefile
├── bin/
│   ├── _agent-here-common.sh
│   ├── codex-here
│   ├── claude-here
│   └── pi-here
├── sandbox/
│   └── kits/
│       ├── codex/spec.yaml
│       ├── claude/spec.yaml
│       └── pi/spec.yaml
├── scripts/
│   └── install-python.sh
└── tests/
    ├── test-launchers.sh
    ├── test-layout.sh
    └── test-sandbox-smoke.sh
```
