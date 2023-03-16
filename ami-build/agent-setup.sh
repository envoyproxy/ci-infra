#!/bin/bash

set -e

echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

# https://github.com/microsoft/azure-pipelines-agent/issues/3599#issuecomment-1083564092
export AZP_AGENT_USE_LEGACY_HTTP=true

ARCH=$(dpkg --print-architecture)
BAZELISK_VERSION=1.11.0

sudo apt-get -qq update
sudo apt-get -qq upgrade -y
sudo apt-get -qq install -y apt-transport-https ca-certificates gnupg-agent software-properties-common wget

wget -q -O - https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key adv --list-public-keys --with-fingerprint --with-colons 0EBFCD88 2>/dev/null | grep 'fpr' | head -n1 | grep '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'
sudo add-apt-repository -y "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install bazelisk
wget -qO - "https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VERSION}/bazelisk-linux-amd64" | sudo tee /usr/local/bin/bazel > /dev/null
sudo chmod +x /usr/local/bin/bazel

# Install skopeo
# https://software.opensuse.org/download/package?package=skopeo&project=devel%3Akubic%3Alibcontainers%3Astable#manualUbuntu
echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04/ /' | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list > /dev/null
curl -fsSL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/null

sudo apt-get -qq update
sudo apt-get -qq install -y docker-ce docker-ce-cli containerd.io git awscli jq inotify-tools expect skopeo zstd libicu67 libssl3 libicu70

sudo mkdir -p /etc/docker
echo '{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}' | sudo tee /etc/docker/daemon.json
echo "::1 localhost" | sudo tee -a /etc/hosts > /dev/null

sudo systemctl enable docker
sudo systemctl start docker

sudo useradd -ms /bin/bash -G docker azure-pipelines
sudo mkdir -p /srv/azure-pipelines
sudo chown -R azure-pipelines:azure-pipelines /srv/azure-pipelines/

[[ "${ARCH}" == "amd64" ]] && ARCH=x64
# TODO(phlax): Switch off pre-release agent version asap.
AGENT_VERSION=3.217.0
AGENT_FILE=vsts-agent-linux-${ARCH}-${AGENT_VERSION}

sudo -u azure-pipelines /bin/bash -c "wget -q -O - https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/${AGENT_FILE}.tar.gz | tar zx -C /srv/azure-pipelines"
sudo /srv/azure-pipelines/bin/installdependencies.sh

sudo -u azure-pipelines /bin/bash -c 'mkdir -p /home/azure-pipelines/.ssh && touch /home/azure-pipelines/.ssh/known_hosts'
sudo -u azure-pipelines /bin/bash -c 'ssh-keyscan github.com | tee /home/azure-pipelines/.ssh/known_hosts'
sudo -u azure-pipelines /bin/bash -c 'ssh-keygen -l -f /home/azure-pipelines/.ssh/known_hosts | grep github.com | grep "SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8"'

sudo chown root:root /home/ubuntu/scripts/*.sh
sudo chmod 0755 /home/ubuntu/scripts/*.sh
sudo mv /home/ubuntu/scripts/*.sh /usr/local/bin

sudo install-bazel-remote.sh
sudo rm -rf /usr/local/bin/install-bazel-remote.sh
sudo useradd -rms /bin/bash bazel-remote

rm -rf /home/ubuntu/scripts /home/ubuntu/services

# Allow passwordless sudo for azp worker
echo 'azure-pipelines ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers
