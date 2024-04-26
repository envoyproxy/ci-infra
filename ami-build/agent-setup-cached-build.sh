#!/bin/bash -eu

set -o pipefail

. ./version.sh

# shellcheck source=ami-build/scripts/install-fun.sh
. /home/ubuntu/scripts/install-fun.sh


agent_setup_cached_build
