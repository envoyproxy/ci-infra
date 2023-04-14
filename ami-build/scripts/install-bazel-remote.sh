#!/usr/bin/env bash

set -eu -o pipefail

ARCH="$(dpkg --print-architecture)"
if [[ "${ARCH}" == "amd64" ]]; then
    ARCH="x86_64"
fi

export ARCH

sudo wget -O /usr/local/bin/bazel-remote "https://github.com/buchgr/bazel-remote/releases/download/v2.4.0/bazel-remote-2.4.0-linux-${ARCH}"
sudo chmod 0755 /usr/local/bin/bazel-remote
