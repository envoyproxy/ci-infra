#!/bin/bash -eu

set -o pipefail

# The version of the AZP agent to use.
# See https://github.com/microsoft/azure-pipelines-agent/releases.
AGENT_VERSION=2.218.1
export DEBIAN_FRONTEND=noninteractive
# Determine the architecture and package versions.
ARCH=$(dpkg --print-architecture)
if [ "${ARCH}" = "amd64" ]; then
  ARCH="x64"
  AWS_ARCH="x86_64"
else
  AWS_ARCH="aarch64"
fi
AGENT_FILE=vsts-agent-linux-${ARCH}-${AGENT_VERSION}

# Upgrade installed packages.
apt-get -qq update
apt-get -qq upgrade -y

# Insgtall required packages.
apt-get -qq install -y \
  git `# Needed by the AZP agent` \
  inotify-tools `# Needed by the AZP agent` \
  jq `# Needed in the run script.` \
  unzip `# Needed to install AWS CLI.` \
  wget  `# Used in this script.`

# Workaround for AWSCLI that requires an older version of libssl.
# Forcing libssl.so.1.1.
# See https://github.com/microsoft/azure-pipelines-agent/issues/3834#issuecomment-1231742801.
LIBSSL1_DIR="/tmp/libssl1"
wget -q -r -l1 -np \
  -P "${LIBSSL1_DIR}" \
  -A 'libssl1.1_1.1.1*ubuntu*amd64.deb' \
  "http://security.ubuntu.com/ubuntu/pool/main/o/openssl/"
LIBSSL1_PACKAGE=`find "${LIBSSL1_DIR}" -type f -name \*.deb | sort | head -n 1`
dpkg -i "${LIBSSL1_PACKAGE}"
sed -i 's/openssl_conf = openssl_init/#openssl_conf = openssl_init/g' /etc/ssl/openssl.cnf

# Setup a local user to run the AZP agent.
groupadd azure-pipelines
useradd -ms /bin/bash -g azure-pipelines azure-pipelines
sudo mkdir -p /srv/azure-pipelines
sudo chown -R azure-pipelines:azure-pipelines /srv/azure-pipelines/

# Install the AZP agent.
sudo -u azure-pipelines /bin/bash -c "wget -q -O - https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/${AGENT_FILE}.tar.gz | tar zx -C /srv/azure-pipelines"
# The following script tries to install both liblttng-ust0 and liblttng-ust1,
# only one is expected to exist, so ignoring errors here.
set +e
sudo /srv/azure-pipelines/bin/installdependencies.sh
set -e

sudo -u azure-pipelines /bin/bash -c 'mkdir -p /home/azure-pipelines/.ssh && touch /home/azure-pipelines/.ssh/known_hosts'
sudo -u azure-pipelines /bin/bash -c 'ssh-keyscan github.com | tee /home/azure-pipelines/.ssh/known_hosts'

# Allow password-less sudo for the AZP agent.
echo 'azure-pipelines ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers

# Install AWS CLI.
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
wget -q -O awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"
unzip awscliv2.zip
./aws/install
