FROM node:24-trixie

ENV USERNAME=developer
ENV HOME=/home/${USERNAME}

# Install system packages

USER root

RUN <<'EOF'

# Add the official MongoDB repository and install mongosh
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg -o /etc/apt/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian $(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)/mongodb-org/8.0 main" | tee /etc/apt/sources.list.d/mongodb-org-8.0.list

apt-get update
packages="
sudo
openssh-client
openssh-server
telnet
supervisor
ripgrep
git
mc
htop
iputils-ping
inetutils-traceroute
mtr-tiny
mongodb-mongosh
xauth
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
sudo chown 1000:1000 /home/developer/.ssh
sudo chmod 700 /home/developer/.ssh
# fsGroup widens the mounted Secret to 0640; sshd rejects that. Copy onto the PVC as 0600.
if [ -f /mnt/ssh-host-key/ssh_host_key ]; then
  sudo install -m 600 -o 1000 -g 1000 /mnt/ssh-host-key/ssh_host_key /home/developer/.ssh/ssh_host_key
fi

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

ENV PATH="${PATH}:${HOME}/.local/bin:${HOME}/.local/share/pnpm/bin"

RUN <<'EOF'
# Run commands as user

mkdir -p ${HOME}/.ssh && sudo chmod 700 ${HOME}/.ssh
mkdir -p ${HOME}/.local/bin

# Install a bin tool
mkdir -p ~/.config/bin && echo "{\"default_path\": \"${HOME}/.local/bin\"}" > ~/.config/bin/config.json
# TODO: Rework when https://github.com/marcosnils/bin/issues/192 is fixed
curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64 && chmod +x /tmp/bin_install && /tmp/bin_install install github.com/marcosnils/bin && rm /tmp/bin_install

# Install useful tools through bin
bin install get.helm.sh
bin install github.com/helmwave/helmwave -n *.tar.gz
bin install github.com/cli/cli
bin install github.com/tstack/lnav

# TODO: Rework to bin when https://github.com/marcosnils/bin/issues/314 is fixed
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install APM – Agent Package Manager
curl -sSL https://aka.ms/apm-unix | sh

# Install Cursor Agent
curl https://cursor.com/install -fsS | bash


# Install NVM in the user's home directory
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.41.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Configure PNPM
corepack enable pnpm

# Install userspace Node tools
pnpm add -g --allow-build=@nubjs/nub @antfu/ni @nubjs/nub playwright-core
na playwright-core install-deps

EOF

WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]

LABEL devcontainer.metadata='[{ \
  "workspaceFolder": "/app", \
  "remoteUser": "developer", \
}]'