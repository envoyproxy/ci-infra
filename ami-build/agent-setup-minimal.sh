#!/bin/bash -eu

set -o pipefail

AGENT_VERSION=3.218.0

# shellcheck source=ami-build/scripts/install-fun.sh
. /home/ubuntu/scripts/install-fun.sh


agent_setup_minimal
