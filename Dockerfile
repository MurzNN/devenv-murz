FROM lucasvmigotto/devenv:node-24.20.0-pnpm-ubuntu

RUN <<EOF

apt update
apt install -y --no-install-recommends mc htop
rm -rf /var/lib/apt/lists/*

curl https://cursor.com/install -fsS | bash

# Install a bin tool
sudo mkdir -p ~/.config/bin && sudo echo '{"default_path": "/usr/local/bin"}' > ~/.config/bin/config.json
curl -sL -o /tmp/bin_install https://github.com/marcosnils/bin/releases/download/v0.29.4/bin_0.29.4_linux_amd64 && sudo chmod +x /tmp/bin_install && sudo /tmp/bin_install install github.com/marcosnils/bin /usr/local/bin && sudo rm /tmp/bin_install

EOF
