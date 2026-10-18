FROM lucasvmigotto/devenv:node-24.20.0-pnpm-ubuntu

USER root

# Install system packages

RUN <<'EOF'

apt-get update
packages="
mc
htop
openssh-client
openssh-server
telnet
supervisor
"
apt-get install -y --no-install-recommends $packages
rm -rf /var/lib/apt/lists/*

EOF

RUN <<'EOF'
# Run commands as root user

# # Install a root bin tool
# mkdir -p ~/.config/bin && echo "{\"default_path\": \"/usr/local/bin\"}" > ~/.config/bin/config.json
# curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64 && chmod +x /tmp/bin_install && /tmp/bin_install install github.com/marcosnils/bin && rm /tmp/bin_install

# Create environment directories
mkdir /cache && chmod 777 /cache
mkdir /app && chown 1000:1000 /app
chmod 777 /var/log/supervisor

cat > /etc/supervisor/supervisord.conf <<'CONF'
[unix_http_server]
file=/tmp/supervisor.sock
chmod=0700

[supervisord]
nodaemon=true
logfile=/tmp/supervisord.log
pidfile=/tmp/supervisord.pid

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

# Automatically load all service configs from the conf.d directory
[include]
files = /app/deploy/supervisor/*.conf
CONF

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
bin install github.com/helmwave/helmwave
bin install github.com/cli/cli

# Install Cursor Agent
curl https://cursor.com/install -fsS | bash

EOF

WORKDIR /app

ENTRYPOINT ["/usr/bin/supervisord","-c","/etc/supervisor/supervisord.conf"]
