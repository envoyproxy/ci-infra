#!/usr/bin/env bash

set -eu -o pipefail

export ARCH=$(dpkg --print-architecture)
[[ "${ARCH}" == "amd64" ]] && ARCH="x86_64"

sudo wget -O /usr/local/bin/bazel-remote https://github.com/buchgr/bazel-remote/releases/download/v2.4.0/bazel-remote-2.4.0-linux-${ARCH}
sudo chmod 0755 /usr/local/bin/bazel-remote
