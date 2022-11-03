#!/usr/bin/env bash

set -eu -o pipefail

export ARCH=$(dpkg --print-architecture)
[[ "${ARCH}" == "amd64" ]] && ARCH="x86_64"

sudo wget -O /usr/local/bin/bazel-remote https://github.com/buchgr/bazel-remote/releases/download/v2.3.9/bazel-remote-2.3.9-linux-${ARCH}
sudo chmod 0755 /usr/local/bin/bazel-remote
