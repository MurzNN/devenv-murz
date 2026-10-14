FROM lucasvmigotto/devenv:node-24.20.0-pnpm-ubuntu

USER root

# Install system packages

RUN <<'EOF'

apt-get update
packages="
mc
htop
openssh-client
telnet
xz-utils
"
apt-get install -y --no-install-recommends $packages
rm -rf /var/lib/apt/lists/*

EOF

# Install S6-Overlay.
ARG S6_OVERLAY_VERSION=3.2.3.2
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && rm /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && rm /tmp/s6-overlay-x86_64.tar.xz


RUN <<'EOF'
# Run commands as root user

# Create environment directories
mkdir /cache && chmod 777 /cache
mkdir /app && chown 1000:1000 /app

EOF

USER ${DEVENV_USER}

ENV PATH="${PATH}:${HOME}/.local/bin:${HOME}/.local/share/pnpm/bin"

RUN <<'EOF'
# Run commands as user

mkdir -p ${HOME}/.local/bin

# Install a bin tool
mkdir -p ~/.config/bin && echo "{\"default_path\": \"${HOME}/.local/bin\"}" > ~/.config/bin/config.json
curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64 && chmod +x /tmp/bin_install && /tmp/bin_install install github.com/marcosnils/bin && rm /tmp/bin_install

# Install userspace tools
pnpm install -g @antfu/ni
bin install get.helm.sh

# Install Cursor Agent
curl https://cursor.com/install -fsS | bash

EOF

WORKDIR /app

ENTRYPOINT ["/init"]
