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
  rsync postgresql-client shellcheck file sqlite3 socat \
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

# browser libraries required by Chrome for Testing (the set agent-browser's
# `install --with-deps` would install, plus xvfb for --headed on a displayless host)
RUN apt-get update && apt-get install -y --no-install-recommends \
  libxcb-shm0 libx11-xcb1 libx11-6 libxcb1 libxext6 libxrandr2 libxcomposite1 \
  libxcursor1 libxdamage1 libxfixes3 libxi6 libxrender1 libxshmfence1 \
  libgtk-3-0t64 libpangocairo-1.0-0 libpango-1.0-0 libatk1.0-0t64 \
  libcairo-gobject2 libcairo2 libgdk-pixbuf-2.0-0 libdbus-1-3 \
  libatk-bridge2.0-0t64 libatspi2.0-0t64 libcups2t64 \
  libasound2t64 libfreetype6 libfontconfig1 libnss3 libnss3-tools libnspr4 \
  libdrm2 libxkbcommon0 libgbm1 xvfb \
  fonts-noto-color-emoji fonts-noto-cjk fonts-freefont-ttf && \
  rm -rf /var/lib/apt/lists/*

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
  brew install ripgrep bat fd fzf uv rclone yq && \
  brew install gh && \
  brew install awscli && \
  brew install openjdk@17 maven gradle && \
  brew install kubernetes-cli && \
  brew install go node'"

# install global npm tools
RUN su - ubuntu -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && \
  npm install -g typescript && \
  npm install -g cf@latest && \
  npm install -g --allow-scripts=agent-browser agent-browser@latest && \
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent'"

# agent-browser: download Chrome for Testing. The CLI searches
# $HOME/.agent-browser/browsers, but the launchers mount the persisted host home
# over /home/ubuntu, so keep Chrome in /opt and point the CLI there with
# AGENT_BROWSER_EXECUTABLE_PATH.
RUN su - ubuntu -c "bash -lc 'eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && agent-browser install'" && \
  mkdir -p /opt/agent-browser && \
  mv /home/ubuntu/.agent-browser/browsers/* /opt/agent-browser/ && \
  ln -sfn "$(ls -d /opt/agent-browser/chrome-* | tail -n 1)/chrome" /opt/agent-browser/chrome && \
  rm -rf /home/ubuntu/.agent-browser && \
  chown -R ubuntu:ubuntu /opt/agent-browser

ENV AGENT_BROWSER_EXECUTABLE_PATH=/opt/agent-browser/chrome

COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER ubuntu
WORKDIR /home/ubuntu

# keep Homebrew tools available in login shells
RUN echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"' >> /home/ubuntu/.profile

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
