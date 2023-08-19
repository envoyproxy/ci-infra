#!/usr/bin/env bash

set -eu -o pipefail

BAZEL_REMOTE_VERSION=2.4.1

export ARCH=$(dpkg --print-architecture)
[[ "${ARCH}" == "amd64" ]] && ARCH="x86_64"

sudo wget -O /usr/local/bin/bazel-remote https://github.com/buchgr/bazel-remote/releases/download/v${BAZEL_REMOTE_VERSION}/bazel-remote-${BAZEL_REMOTE_VERSION}-linux-${ARCH}
sudo chmod 0755 /usr/local/bin/bazel-remote
