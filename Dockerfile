FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
  TZ=America/St_Johns \
  HOME=/home/ubuntu \
  NPM_CONFIG_MIN_RELEASE_AGE=7 \
  PATH=/home/linuxbrew/.linuxbrew/bin:$PATH

# build and system utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential curl git ca-certificates pkg-config wget xz-utils procps git-crypt \
  iputils-ping dnsutils traceroute iproute2 tcpdump htop lsof strace

# git needs openssh-client
RUN apt-get install -y openssh-client

# common tools
RUN apt-get install -y sudo wget git curl \
  vim less nano bash-completion zsh locales tzdata \
  iproute2 net-tools lsof htop unzip zip gnupg man-db tree jq \
  rsync postgresql-client shellcheck \
  ansible incus-client \
  docker.io docker-compose-v2 \
  python3 python3-pip python3-venv

RUN usermod -aG docker ubuntu

RUN ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
  echo "${TZ}" > /etc/timezone

# terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" > /etc/apt/sources.list.d/hashicorp.list && \
  apt-get update && apt-get install -y terraform

# chromium dependencies for playwright
RUN python3 -m venv /tmp/playwright-venv && \
  /tmp/playwright-venv/bin/pip install playwright && \
  /tmp/playwright-venv/bin/playwright install-deps chromium && \
  rm -rf /tmp/playwright-venv

# create a non-root user to install Homebrew
RUN chown -R ubuntu:ubuntu /home/ubuntu

# install Homebrew (non-interactive) using ubuntu+sudown
WORKDIR /root
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu && chmod 0440 /etc/sudoers.d/ubuntu

# run installer as ubuntu (has sudo) non-interactively
RUN su - ubuntu -c "NONINTERACTIVE=1 /bin/bash -lc 'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash'"

# ensure brew is available and install tools as ubuntu
RUN su - ubuntu -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  brew install --cask copilot-cli codex claude-code && \
  brew install ripgrep bat fd fzf uv rclone && \
  brew install gh && \
  brew install awscli && \
  brew install openjdk@17 maven gradle && \
  brew install kubernetes-cli && \
  brew install go node'"

# install global npm tools
RUN su - ubuntu -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  npm install -g typescript && \
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent'"

COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER ubuntu
WORKDIR /home/ubuntu

# keep Homebrew tools available in login shells
RUN echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"' >> /home/ubuntu/.profile

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
