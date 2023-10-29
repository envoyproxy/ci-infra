#!/bin/bash -eu

set -o pipefail

AGENT_VERSION=3.227.2

# shellcheck source=ami-build/scripts/install-fun.sh
. /home/ubuntu/scripts/install-fun.sh


agent_setup_cached_build
