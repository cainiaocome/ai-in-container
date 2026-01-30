FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
  HOME=/home/ubuntu \
  PYENV_ROOT=/home/ubuntu/.pyenv \
  PATH=/home/linuxbrew/.linuxbrew/bin:/home/ubuntu/.pyenv/bin:/home/ubuntu/.pyenv/shims:$PATH \
  PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto" \
  CFLAGS="-O3 -march=native -fomit-frame-pointer -funroll-loops -pipe" \
  LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

# python dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential curl git ca-certificates pkg-config libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncursesw5-dev libgdbm-dev libnss3-dev liblzma-dev \
  libffi-dev tk-dev libncurses-dev wget xz-utils procps sudo \
  vim less nano bash-completion zsh locales tzdata iproute2 net-tools lsof htop unzip zip gnupg man-db tree jq

# git needs openssh-client
RUN apt-get install -y openssh-client

# chromium dependencies for playwright
RUN apt-get install -y python3 python3-pip python3-venv
RUN python3 -m venv /tmp/playwright-venv && \
  /tmp/playwright-venv/bin/pip install playwright && \
  /tmp/playwright-venv/bin/playwright install-deps chromium && \
  rm -rf /tmp/playwright-venv

# create a non-root user to install Homebrew
RUN chown -R ubuntu:ubuntu /home/ubuntu

# install Homebrew (non-interactive) and pyenv via brew using ubuntu+sudown
WORKDIR /root
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu && chmod 0440 /etc/sudoers.d/ubuntu

# run installer as ubuntu (has sudo) non-interactively
RUN su - ubuntu -c "NONINTERACTIVE=1 /bin/bash -lc 'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash'"

# ensure brew is available and install pyenv as ubuntu
RUN su - ubuntu -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  brew install pyenv && \
  brew install pyenv-virtualenv && \
  brew install --cask copilot-cli && \
  brew install ripgrep bat fd fzf uv && \
  brew install gh && \
  brew install go node'"

# install TypeScript globally
RUN su - ubuntu -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  npm install -g typescript'"

# default pyenv
RUN echo "testenv" > /.python-version

# script will handle initializing pyenv and installing Python versions at runtime
COPY scripts/install-python.sh /usr/local/bin/install-python.sh
RUN chmod +x /usr/local/bin/install-python.sh

USER ubuntu
WORKDIR /home/ubuntu

# persist env for interactive shells
RUN echo 'export PYENV_ROOT="/home/ubuntu/.pyenv"' >> /home/ubuntu/.profile && \
  echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"' >> /home/ubuntu/.profile

CMD ["bash"]
