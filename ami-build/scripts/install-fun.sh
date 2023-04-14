#!/bin/bash -eux

set -o pipefail


if [[ -z "$AGENT_VERSION" ]]; then
   echo "AGENT_VERSION unset, exiting" >&2
   exit 1
fi

UNAME_ARCH=$(dpkg --print-architecture)
if [[ "${UNAME_ARCH}" == "amd64" ]]; then
    ARCH=x64
    FULL_ARCH=x86_64
else
    ARCH="$UNAME_ARCH"
    FULL_ARCH="$UNAME_ARCH"
fi
export ARCH
AGENT_FILE="vsts-agent-linux-${ARCH}-${AGENT_VERSION}"
AGENT_DL_URL="https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/${AGENT_FILE}.tar.gz"
APT_PKGS_AGENT=(
    awscli
    git
    inotify-tools
    jq)
APT_PKGS_BASE=(
    apt-transport-https
    ca-certificates
    gnupg-agent
    software-properties-common
    wget)
APT_PKGS_BUILD=(
    docker-ce
    docker-ce-cli
    containerd.io
    expect
    skopeo
    zstd)
AZP_USER=azure-pipelines
BAZEL_REMOTE_VERSION=2.4.0
BAZEL_REMOTE_INSTALL_URL="https://github.com/buchgr/bazel-remote/releases/download/v${BAZEL_REMOTE_VERSION}/bazel-remote-${BAZEL_REMOTE_VERSION}-linux-${FULL_ARCH}"
BAZELISK_VERSION=1.11.0
BAZELISK_INSTALL_URL="https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VERSION}/bazelisk-linux-${UNAME_ARCH}"
export DEBIAN_FRONTEND=noninteractive
DOCKER_PK=9DC858229FC7DD38854AE2D88D81803C0EBFCD88
# Hardcoded Github SSH RSA SHA to ensure we download the known key.
# This must be updated when Github change their public key.
GITHUB_PK_SHA=uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s
# https://software.opensuse.org/download/package?package=skopeo&project=devel%3Akubic%3Alibcontainers%3Astable#manualUbuntu
KUBIC_REPO_URL="https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_20.04"

alias apt-get="apt-get -qq"


_run_as_azp () {
    sudo -u "$AZP_USER" /bin/bash -c "$1"
}


agent_install_cleanup () {
    chown root:root /home/ubuntu/scripts/*.sh
    mv /home/ubuntu/scripts/run-fun.sh /usr/local/share
    chmod 0755 /home/ubuntu/scripts/*.sh
    rm /home/ubuntu/scripts/install-fun.sh
    mv /home/ubuntu/scripts/*.sh /usr/local/bin
    rm -rf /home/ubuntu/scripts /home/ubuntu/services
}


apt_add_git () {
    apt-add-repository -y ppa:git-core/ppa
}


apt_add_docker () {
    wget -q -O - https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key adv --list-public-keys --with-fingerprint --with-colons 0EBFCD88 2>/dev/null \
        | grep 'fpr' \
        | head -n1 \
        | grep "$DOCKER_PK"
    add-apt-repository -y \
         "deb [arch=${UNAME_ARCH}] https://download.docker.com/linux/ubuntu \
         $(lsb_release -cs) \
         stable"
}


apt_add_skopeo () {
    echo "${KUBIC_REPO_URL} /" \
        | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    curl -fsSL "${KUBIC_REPO_URL}/Release.key" \
        | gpg --dearmor \
        | tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg \
               > /dev/null
}


apt_cleanup () {
    apt-get autoremove -y --purge
    rm -rf /var/cache/apt /var/lib/apt/lists/*
}


apt_install_base_pkgs () {
    if ! apt-get install -y "${APT_PKGS_BASE[@]}"; then
        echo "Waiting on Ubuntu's crapt setup ..."
        sleep 5
        apt-get install -y "${APT_PKGS_BASE[@]}"
    fi
}


apt_install_pkgs () {
    echo "Install packages: ${*}"
    apt-get update
    apt-get install --no-install-recommends -y "$@"
}


apt_setup () {
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    systemctl stop unattended-upgrades
    sleep 1
    apt-get remove -y --purge unattended-upgrades
    apt-get update
    apt-get upgrade -y
}


azp_setup_user () {
    useradd -ms /bin/bash "$AZP_USER"
    mkdir -p "/srv/${AZP_USER}"
    chown -R "${AZP_USER}:${AZP_USER}" "/srv/${AZP_USER}/"
    echo "${AZP_USER} ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers
}


azp_install_agent () {
    echo "Installing agent: ${AGENT_DL_URL}"
    _run_as_azp "wget -q -O - ${AGENT_DL_URL} | tar zx -C /srv/${AZP_USER}"
    if [[ "$ARCH" == "arm64" ]]; then
        sed -i \
             s/amd64/arm64/g \
             "/srv/${AZP_USER}/bin/installdependencies.sh"
        sed -i \
             s#http://security.ubuntu.com/ubuntu#http://ports.ubuntu.com/ubuntu-ports/#g \
             "/srv/${AZP_USER}/bin/installdependencies.sh"
    fi
    "/srv/${AZP_USER}/bin/installdependencies.sh"
}


configure_docker () {
    mkdir -p /etc/docker
    echo '{
"ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}' | tee /etc/docker/daemon.json
    echo "::1 localhost" | tee -a /etc/hosts
}


install_bazel () {
    echo "Installing bazel/isk (${BAZELISK_VERSION}) from: ${BAZELISK_INSTALL_URL}"
    wget -qO - "${BAZELISK_INSTALL_URL}" \
        | tee /usr/local/bin/bazel \
               > /dev/null
    chmod +x /usr/local/bin/bazel
}


install_bazel_remote () {
    echo "Installing bazel-remote (${BAZEL_REMOTE_VERSION}) from: ${BAZEL_REMOTE_INSTALL_URL}"
    wget -O \
         /usr/local/bin/bazel-remote \
         "$BAZEL_REMOTE_INSTALL_URL"
    chmod 0755 /usr/local/bin/bazel-remote
}


ssh_client_github () {
    _run_as_azp "mkdir -p /home/${AZP_USER}/.ssh && touch /home/${AZP_USER}/.ssh/known_hosts"
    _run_as_azp "ssh-keyscan github.com | tee /home/${AZP_USER}/.ssh/known_hosts"
    _run_as_azp "ssh-keygen -l -f /home/${AZP_USER}/.ssh/known_hosts | grep github.com | grep \"SHA256:${GITHUB_PK_SHA}\""
}


# Agent setups

_agent_setup_init () {
    apt_setup
    apt_install_base_pkgs
    apt_add_git
}


_agent_setup_finalize () {
    azp_setup_user
    azp_install_agent
    ssh_client_github
    apt_cleanup
    agent_install_cleanup
}


agent_setup_build () {
    _agent_setup_init
    apt_add_docker
    apt_add_skopeo
    apt_install_pkgs "${APT_PKGS_AGENT[@]}" "${APT_PKGS_BUILD[@]}"
    install_bazel
    install_bazel_remote
    configure_docker
    _agent_setup_finalize
}


agent_setup_minimal () {
    _agent_setup_init
    apt_install_pkgs  "${APT_PKGS_AGENT[@]}"
    _agent_setup_finalize
}
