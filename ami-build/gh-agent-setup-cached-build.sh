#!/bin/bash -eu

set -o pipefail

AGENT_VERSION=2.311.0
AGENT_SHA=5d13b77e0aa5306b6c03e234ad1da4d9c6aa7831d26fd7e37a3656e77153611e

# shellcheck source=ami-build/scripts/install-fun.sh
. /home/ubuntu/scripts/install-fun.sh


gh_agent_setup_cached_build
