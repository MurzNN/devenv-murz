FROM lucasvmigotto/devenv:node-24.20.0-pnpm-ubuntu

RUN <<EOF

apt update
apt install -y --no-install-recommends mc htop
rm -rf /var/lib/apt/lists/*

curl https://cursor.com/install -fsS | bash

# Install a bin tool
sudo mkdir -p ~/.config/bin && echo '{"default_path": "/usr/local/bin"}' > ~/.config/bin/config.json
sudo curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64  && chmod +x /tmp/bin_install && /tmp/bin_install install github.com/marcosnils/bin /usr/local/bin && rm /tmp/bin_install

EOF
