#!/bin/bash -eu

set -o pipefail

# shellcheck source=ami-build/scripts/versions.sh
. /home/ubuntu/scripts/versions.sh

# shellcheck source=ami-build/scripts/install-fun.sh
. /home/ubuntu/scripts/install-fun.sh


agent_setup_minimal
