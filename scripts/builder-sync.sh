#!/usr/bin/env bash
# Copy the current project checkout from this computer into the builder VM.
# Generated output/ files are left out; the VM keeps its own build output.
#
# Start the VM first, then run:
#   ./scripts/builder-sync.sh
#
# The checkout is placed at ~/bootc-gnome inside the VM. Requires rsync and
# the VM's SSH key created by ./scripts/prepare-builder.sh.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime="$repo_root/output/builder/runtime"
port="${BUILDER_SSH_PORT:-2222}"
known_hosts="$runtime/known_hosts"

if [[ ! -f "$runtime/id_ed25519" ]]; then
    printf 'Builder SSH key not found; start the VM with ./scripts/start-builder.sh first.\n' >&2
    exit 1
fi
if ! command -v rsync >/dev/null 2>&1; then
    printf 'Required host tool not found: rsync\n' >&2
    exit 1
fi

rsync --archive --compress --delete \
    --exclude=/output/ \
    --exclude=/output \
    -e "ssh -i $runtime/id_ed25519 -p $port -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$known_hosts" \
    "$repo_root/" builder@127.0.0.1:bootc-gnome/

printf 'Synchronized checkout to ~/bootc-gnome in builder VM.\n'
