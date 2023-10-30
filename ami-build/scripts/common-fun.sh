#!/bin/bash -eu

set -o pipefail


AZP_USER=azure-pipelines
GH_USER=runner


_run_as() {
    local user="$1"
    shift
    local cmd="$*"
    local tmpexec
    tmpexec="$(mktemp)"
    echo "$cmd" > "$tmpexec"
    chmod +x "$tmpexec"
    chown "$user" "$tmpexec"
    sudo -u "$user" "$tmpexec"
    rm -rf "$tmpexec"
}
