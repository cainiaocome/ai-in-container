# AI in Container — Docker Sandbox experiment

This branch replaces the launcher runtime from a normal Docker container with
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). It preserves the
original launcher identity model: **one runtime per agent**, independent of the
project currently being worked on.

The three stable sandboxes are therefore:

```text
codex-here
claude-here
pi-here
```

Each is a persistent microVM with its own filesystem, Linux kernel, Docker
daemon, agent state, Docker images, and build cache.

## Important design choice

The project **does not use Docker's Codex or Claude Code agent images**.

`Dockerfile` starts only from the generic
`docker/sandbox-templates:shell-docker` runtime because Docker Sandboxes needs
its `agent` user, VM integration, and in-VM Docker Engine. The coding agents are
then installed by this repository itself:

- `@openai/codex`
- `@anthropic-ai/claude-code`
- `@earendil-works/pi-coding-agent`

The three sandbox kits under `sandbox/kits/` only describe the entrypoint and
reference our image. Agent versions therefore come from this repository's
Docker build, not from Docker's agent-specific templates.

## Architecture

```text
                         host workspace root
                         /work/projects
                              │
                direct workspace passthrough
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
   codex-here VM       claude-here VM        pi-here VM
   persistent HOME     persistent HOME       persistent HOME
   private dockerd     private dockerd       private dockerd
   Docker cache        Docker cache          Docker cache
          │                   │                   │
          └──── launcher selects current project with ────┘
                       sbx exec --workdir "$PWD"
```

A project does **not** get its own VM. Running Codex in ten projects still uses
one `codex-here` VM.

The agent can control Docker inside its own microVM. It does **not** receive the
host's `/var/run/docker.sock`.

## Why a workspace root is needed

The old Docker implementation could recreate the same named container on every
invocation and bind-mount only the current `$PWD`:

```text
codex-here container
    + current project bind mount
```

Docker Sandboxes works differently: a sandbox's workspace mounts are fixed when
the VM is created. An existing named VM cannot later replace its primary
workspace with a different host directory.

To keep one VM per agent, this branch mounts a stable **workspace root** once,
then changes only the process working directory for each invocation:

```text
/work/projects              # mounted once when codex-here VM is created
├── project-a
├── project-b
└── project-c

cd project-a && codex-here  -> sbx exec -w /work/projects/project-a codex-here ...
cd project-b && codex-here  -> sbx exec -w /work/projects/project-b codex-here ...
```

Set the root explicitly when you know where your repositories live:

```bash
export AGENT_HERE_WORKSPACE_ROOT="$HOME/src"
```

The launcher deliberately does **not** default to mounting all of `$HOME`,
because that would unnecessarily expose SSH keys and unrelated files to the
agent. If `AGENT_HERE_WORKSPACE_ROOT` is unset when a VM is first created, the
launcher chooses:

- the parent directory of the current Git repository; or
- outside Git, the parent directory of the current working directory.

That usually covers sibling project directories while keeping the mount much
narrower than `$HOME`.

Because Docker Sandbox workspace mounts are fixed at VM creation time, changing
`AGENT_HERE_WORKSPACE_ROOT` for an already-created VM does not update it. Remove
that agent VM once and recreate it:

```bash
sbx rm codex-here
AGENT_HERE_WORKSPACE_ROOT="$HOME/src" ./bin/codex-here
```

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

From any project below the configured workspace root, run one of the launchers:

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

The default sandbox identity depends only on the agent:

```text
Codex       -> codex-here
Claude Code -> claude-here
Pi          -> pi-here
```

It does not include project names, path hashes, or Git repositories.

That means packages installed manually in a VM, agent login state, Docker
images, Docker build cache, and other VM files are reused when the same agent
moves between projects.

List sandboxes:

```bash
sbx ls
```

Stop one without deleting its state:

```bash
sbx stop codex-here
```

Delete one completely when a clean VM is desired:

```bash
sbx rm codex-here
```

Override the fixed name when deliberately creating a separate VM:

```bash
AGENT_HERE_SANDBOX_NAME=codex-experiment ./bin/codex-here
```

## Image selection

This branch defaults to:

```text
ghcr.io/cainiaocome/ai-in-container:docker-sandbox
```

Override it when creating a new VM:

```bash
AGENT_HERE_IMAGE=ghcr.io/example/ai-in-container:dev \
  AGENT_HERE_SANDBOX_NAME=codex-dev \
  ./bin/codex-here
```

An existing VM keeps the image/template it was created from. Remove and recreate
it to switch that VM to a new image.

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
AGENT_HERE_IMAGE=my-ai-sandbox:dev \
  AGENT_HERE_SANDBOX_NAME=codex-local \
  ./bin/codex-here
```

## Authentication

Because this branch deliberately uses self-installed agents instead of Docker's
built-in Codex/Claude integrations, authentication is owned by each agent.

For subscription logins, authenticate from inside the agent as normal:

- Codex: sign in with ChatGPT when Codex prompts
- Claude Code: use `/login`
- Pi: use `/login` and choose the provider

The VM filesystem persists, so login state survives stop/start and follows that
agent between projects. Deleting the VM deletes credentials stored inside it.

## Docker inside the agent VM

No DinD setup is required. `shell-docker` supplies a full Docker Engine inside
the microVM. From Codex, Claude Code, Pi, or an `sbx exec` shell:

```bash
docker version
docker info
docker build .
docker compose up -d
```

The in-VM Docker daemon is isolated from the host daemon, and its images/cache
are shared by all projects handled by that one agent VM.

## Tests

Fast tests do not require Docker Sandboxes or KVM:

```bash
make test
```

They verify:

- launcher argument forwarding and resume/new-session behavior
- the sandbox identity is one fixed VM per agent, not per project
- sibling projects reuse the same agent VM
- `sbx exec --workdir` selects the current project
- custom image/name overrides work at VM creation
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
