FROM node:24-trixie

ENV USERNAME=developer
ENV HOME=/home/${USERNAME}

# Install system packages

USER root

RUN <<'EOF'

# Add the official Eternal Terminal repository and install ET
mkdir -m 0755 -p /etc/apt/keyrings
curl -sSL https://github.com/MisterTea/debian-et/raw/master/et.gpg | tee /etc/apt/keyrings/et.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/et.gpg] https://mistertea.github.io/debian-et/debian-source/ $(grep VERSION_CODENAME /etc/os-release | cut -d= -f2) main" | tee /etc/apt/sources.list.d/et.list

apt-get update
packages="
sudo
openssh-client
openssh-server
telnet
supervisor
ripgrep
git
et
mc
htop
"
apt-get install -y --no-install-recommends $packages
rm -rf /var/lib/apt/lists/*

EOF

RUN <<'EOF'
# Run custom commands as root user
cat <<'ENTRYPOINT' > /entrypoint.sh
#!/usr/bin/env sh

# Save container environment variables for all login shells (SSH, su -)
env | grep -vE '^(HOME|USER|LOGNAME|SHELL|PWD|OLDPWD|SHLVL|_)=' | awk -F= '{printf "export %s=\"%s\"\n", $1, substr($0, index($0,$2))}' | sudo tee /etc/profile.d/container_env.sh >/dev/null
sudo chmod 0644 /etc/profile.d/container_env.sh

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
ENTRYPOINT
chmod +x /entrypoint.sh

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
files = /app/deploy/supervisor/*.conf /etc/supervisor/conf.d/*.conf
CONF

EOF

# Rename the group, user, and move the home directory
RUN groupmod -n ${USERNAME} node \
&& usermod -l ${USERNAME} -d /home/${USERNAME} -m node

# Grant passwordless sudo permissions and set strict file permissions
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}

RUN <<'EOF'
# Run commands as user

mkdir -p ${HOME}/.local/bin

# Install a bin tool
mkdir -p ~/.config/bin && echo "{\"default_path\": \"${HOME}/.local/bin\"}" > ~/.config/bin/config.json
curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64 && chmod +x /tmp/bin_install && /tmp/bin_install install github.com/marcosnils/bin && rm /tmp/bin_install

# Install userspace tools
pnpm install -g --config.ignore-scripts=false @antfu/ni @nubjs/nub

bin install get.helm.sh
bin install github.com/helmwave/helmwave
bin install github.com/cli/cli

# Install APM – Agent Package Manager
curl -sSL https://aka.ms/apm-unix | sh

# Install Cursor Agent
curl https://cursor.com/install -fsS | bash

EOF

ENV PATH="${PATH}:${HOME}/.local/bin:${HOME}/.local/share/pnpm/bin"

WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]
