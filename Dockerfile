FROM lucasvmigotto/devenv:node-24.20.0-pnpm-ubuntu

ENV PATH="${PATH}:/home/developer/.local/share/pnpm/bin"

RUN <<EOF

# We explicitly call 'sudo -H bash' to receive the inner heredoc
sudo -H sh << 'INNER_EOF'

apt update
apt install -y --no-install-recommends mc htop openssh-client telnet
rm -rf /var/lib/apt/lists/*

curl https://cursor.com/install -fsS | bash

# Install a bin tool
mkdir -p ~/.config/bin && echo '{"default_path": "/usr/local/bin"}' > ~/.config/bin/config.json
curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64 && chmod +x /tmp/bin_install && /tmp/bin_install install github.com/marcosnils/bin /usr/local/bin && rm /tmp/bin_install

mkdir /cache && chmod 777 /cache

mkdir /app && chown 1000:1000 /app

INNER_EOF

pnpm install -g @antfu/ni

EOF

ENTRYPOINT tail -f /dev/null
