#!/usr/bin/env bash
# Run a command in the builder VM without opening an interactive login.
# The command and its exit status are passed back to this computer.
#
# Start the VM first, then run a command such as:
#   ./scripts/builder-exec.sh bash -lc 'cd ~/bootc-gnome && ./scripts/build-image.sh'
#
# Requires the VM's SSH key created by ./scripts/prepare-builder.sh.
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
    printf 'Usage: %s COMMAND [ARG ...]\n' "$0" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime="$repo_root/output/builder/runtime"
port="${BUILDER_SSH_PORT:-2222}"
known_hosts="$runtime/known_hosts"

if [[ ! -f "$runtime/id_ed25519" ]]; then
    printf 'Builder SSH key not found; start the VM with ./scripts/start-builder.sh first.\n' >&2
    exit 1
fi

printf -v remote_command '%q ' "$@"
exec ssh -i "$runtime/id_ed25519" -p "$port" \
    -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$known_hosts" \
    builder@127.0.0.1 "$remote_command"
