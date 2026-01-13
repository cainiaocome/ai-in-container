# AI in Container

A Docker image based on Ubuntu 24.04 featuring Python 3.14.2, GitHub Copilot CLI, and modern development tools.

## Features

- **Ubuntu 24.04** base image
- **Homebrew** package manager
- **pyenv** for Python version management
- **Python 3.14.2** with performance optimizations (LTO, O3, native architecture)
- **GitHub Copilot CLI** for AI-powered terminal assistance
- **Modern CLI tools**: ripgrep, bat, fd, fzf
- **Standard utilities**: git, vim, htop, tree, jq, and more

## Quick Start

Use the `ai-here` script to run Copilot CLI in the current directory:

```bash
./ai-here
```

This will:
- Pull the latest image from GitHub Container Registry
- Mount your current directory to `/app/{folder-name}` in the container
- Persist home directory at `~/.homes_for_containers/copilot`
- Start GitHub Copilot CLI with full tool access

## Prerequisites

- Docker installed and running
- `GH_TOKEN` environment variable set with GitHub authentication token

## Manual Usage

Run the container manually:

```bash
docker run -it \
  -e GH_TOKEN \
  -v ~/.homes_for_containers/copilot:/home/ubuntu \
  -v $(pwd):/app/workspace \
  -w /app/workspace \
  ghcr.io/cainiaocome/ai-in-container:main \
  bash
```

## Building Locally

Build the Docker image:

```bash
docker build -t ai-in-container .
```

## CI/CD

The repository includes a GitHub Actions workflow that automatically:
- Builds the Docker image on every push
- Tags images with the branch name
- Pushes to GitHub Container Registry (ghcr.io)

## Installed Tools

### Development Tools
- Python 3.14.2 (via pyenv)
- Git, curl, wget
- Build essentials (gcc, make, pkg-config)

### Editors
- vim, nano

### System Utilities
- htop, tree, jq
- less, man-db
- procps, net-tools, iproute2

### Modern CLI Tools
- **ripgrep** - Fast recursive search
- **bat** - Cat clone with syntax highlighting
- **fd** - Fast find alternative
- **fzf** - Fuzzy finder

### AI Assistant
- GitHub Copilot CLI

## Image Tags

Images are tagged with the branch name:
- `ghcr.io/cainiaocome/ai-in-container:main` - Latest from main branch
- `ghcr.io/cainiaocome/ai-in-container:{branch}` - Other branches

## License

This project is open source and available for use.
