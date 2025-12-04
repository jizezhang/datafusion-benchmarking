#!/usr/bin/env bash

sudo apt update
sudo apt install -y git build-essential python3.12-venv linux-tools-common linux-tools-generic linux-tools-`uname -r` protobuf-compiler
sudo ln -s /usr/lib/linux-tools/6.8.0-88-generic/perf /usr/lib/linux-tools/`uname -r`/perf
curl https://sh.rustup.rs -sSf | sh
. "$HOME/.cargo/env"

# https://docs.docker.com/engine/install/ubuntu/
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker

cargo install flamegraph
cargo install addr2line --features=bin
sudo sh -c 'echo 1 >/proc/sys/kernel/perf_event_paranoid'
sudo sh -c 'echo 0 > /proc/sys/kernel/kptr_restrict'

python3 -m venv ~/venv