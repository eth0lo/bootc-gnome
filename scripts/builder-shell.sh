#!/usr/bin/env bash
# Open an interactive shell in the builder VM.
# Commands run there can use passwordless sudo without changing this
# computer's sudo settings.
#
# Start the VM first, then run:
#   ./scripts/builder-shell.sh
#
# Requires the VM's SSH key created by ./scripts/prepare-builder.sh.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime="$repo_root/output/builder/runtime"
port="${BUILDER_SSH_PORT:-2222}"
known_hosts="$runtime/known_hosts"

if [[ ! -f "$runtime/id_ed25519" ]]; then
    printf 'Builder SSH key not found; start the VM with ./scripts/start-builder.sh first.\n' >&2
    exit 1
fi

exec ssh -i "$runtime/id_ed25519" -p "$port" \
    -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$known_hosts" \
    builder@127.0.0.1
