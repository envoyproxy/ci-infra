#!/bin/bash -eu

set -o pipefail

AGENT_VERSION=3.220.5

# shellcheck source=ami-build/scripts/install-fun.sh
. /home/ubuntu/scripts/install-fun.sh


agent_setup_build
