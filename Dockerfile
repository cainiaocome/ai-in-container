FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
  HOME=/home/builder \
  PYENV_ROOT=/home/builder/.pyenv \
  PATH=/home/linuxbrew/.linuxbrew/bin:/home/builder/.pyenv/bin:/home/builder/.pyenv/shims:$PATH \
  PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto" \
  CFLAGS="-O3 -march=native -fomit-frame-pointer -funroll-loops -pipe" \
  LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential curl git ca-certificates pkg-config libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncursesw5-dev libgdbm-dev libnss3-dev liblzma-dev \
  libffi-dev tk-dev libncurses-dev wget xz-utils procps sudo && \
  rm -rf /var/lib/apt/lists/*

# create a non-root user to install Homebrew
RUN useradd -m builder && chown -R builder:builder /home/builder

# install Homebrew (non-interactive) and pyenv via brew using builder+sudown
WORKDIR /root
RUN echo 'builder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/builder && chmod 0440 /etc/sudoers.d/builder

# run installer as builder (has sudo) non-interactively
RUN su - builder -c "NONINTERACTIVE=1 /bin/bash -lc 'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash'"

# ensure brew is available and install pyenv as builder
RUN su - builder -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  brew install pyenv'"
RUN su - builder -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  brew install --cask copilot-cli'"

USER builder
WORKDIR /home/builder

# initialize pyenv and install Python 3.14 with optimization flags
RUN export PYENV_ROOT=/home/builder/.pyenv && \
  export PATH=/home/linuxbrew/.linuxbrew/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH && \
  eval "$(pyenv init -)" && \
  PYTHON_CONFIGURE_OPTS="${PYTHON_CONFIGURE_OPTS}" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" pyenv install -v 3.14.2 && \
  pyenv global 3.14.2

# persist env for interactive shells
RUN echo 'export PYENV_ROOT="/home/builder/.pyenv"' >> /home/builder/.profile && \
  echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"' >> /home/builder/.profile

CMD ["bash"]
