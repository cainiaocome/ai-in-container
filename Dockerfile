FROM docker.io/docker/sandbox-templates:shell-docker

ARG CODEX_VERSION=latest
ARG CLAUDE_CODE_VERSION=latest
ARG PI_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/St_Johns \
    HOME=/home/agent \
    NPM_CONFIG_MIN_RELEASE_AGE=7 \
    PYENV_ROOT=/home/agent/.pyenv \
    PATH=/home/agent/.pyenv/bin:/home/agent/.pyenv/shims:/usr/local/bin:$PATH \
    PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto" \
    CFLAGS="-O3 -fomit-frame-pointer -funroll-loops -pipe" \
    LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ansible bash-completion build-essential ca-certificates curl dnsutils git git-crypt \
    gnupg gradle htop incus-client iproute2 iputils-ping less libbz2-dev libffi-dev \
    libgdbm-dev liblzma-dev libncurses-dev libncursesw5-dev libnss3-dev libreadline-dev \
    libsqlite3-dev libssl-dev lsof man-db maven nano net-tools openjdk-17-jdk \
    openssh-client pkg-config postgresql-client procps python3 python3-pip python3-venv \
    rclone rsync shellcheck strace sudo tcpdump tk-dev traceroute tree unzip vim wget \
    xz-utils zip zlib1g-dev zsh \
    && rm -rf /var/lib/apt/lists/*

RUN ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone

# Terraform
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg \
    && chmod a+r /etc/apt/keyrings/hashicorp.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo \"$VERSION_CODENAME\") main" \
      > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Node 24 keeps Pi above its Node >=22.19 requirement and is also used to install
# every coding agent ourselves. The generic shell-docker base contains no agent.
RUN curl -fsSL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource.sh \
    && bash /tmp/nodesource.sh \
    && rm /tmp/nodesource.sh \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g \
      "@openai/codex@${CODEX_VERSION}" \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      typescript \
    && npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# pyenv stays user-scoped so install-python.sh can add arbitrary CPython versions
# without modifying the sandbox base image.
USER agent
RUN curl -fsSL https://pyenv.run -o /tmp/pyenv-installer \
    && bash /tmp/pyenv-installer \
    && rm /tmp/pyenv-installer

COPY --chown=agent:agent scripts/install-python.sh /usr/local/bin/install-python.sh
USER root
RUN chmod 0755 /usr/local/bin/install-python.sh \
    && printf '%s\n' \
      'export PYENV_ROOT="$HOME/.pyenv"' \
      'export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:/usr/local/bin:$PATH"' \
      'command -v pyenv >/dev/null && eval "$(pyenv init -)"' \
      >> /etc/sandbox-persistent.sh

USER agent
WORKDIR /home/agent/workspace
