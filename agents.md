## Project Goal

Create a development container with AI tools and modern shell utilities.

### Dockerfile Requirements

**Base Setup:**
- Base image: Ubuntu 24.04
- Install Homebrew and use it to install pyenv
- Install GitHub Copilot CLI using brew ([reference](https://formulae.brew.sh/cask/copilot-cli))

**Shell Utilities:**
- Common utilities: wget, curl, git, vim, htop, tree, jq
- Modern utilities: fzf, bat, ripgrep, fd
- Project manager: uv (install via Homebrew)

**Python Installation:**
- Python versions are **NOT** pre-installed in the image
- A helper script `/usr/local/bin/install-python.sh` is available in the container
- Run the script after container starts to install Python versions manually
- Example: `/usr/local/bin/install-python.sh 3.14.2` (defaults to 3.14.2)
- Multiple versions: `/usr/local/bin/install-python.sh 3.14.2 3.13.7`
- Performance optimization flags are enabled via environment variables (already configured)

**Environment Variables:**
- `PYENV_ROOT=/home/ubuntu/.pyenv`
- `PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto"`
- `CFLAGS="-O3 -march=native -fomit-frame-pointer -funroll-loops -pipe"`
- `LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"`

### CI/CD

A GitHub Actions workflow builds and pushes the Docker image to GitHub Container Registry, using the branch name as the image tag.
