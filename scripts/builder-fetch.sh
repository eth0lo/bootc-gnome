#!/usr/bin/env bash
# Copy files from the builder VM back to this computer.
# By default, fetches the guest's output/ folder into
# output/builder/guest-output/ on the host.
#
# Start the VM first, then run:
#   ./scripts/builder-fetch.sh
#
# To fetch a different folder or choose another destination:
#   ./scripts/builder-fetch.sh bootc-gnome/output/qcow2 ./my-vm-files
#
# Requires rsync and the VM's SSH key created by ./scripts/prepare-builder.sh.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime="$repo_root/output/builder/runtime"
port="${BUILDER_SSH_PORT:-2222}"
known_hosts="$runtime/known_hosts"
remote_path="${1:-bootc-gnome/output/}"
destination="${2:-$repo_root/output/builder/guest-output}"

if [[ ! -f "$runtime/id_ed25519" ]]; then
    printf 'Builder SSH key not found; start the VM with ./scripts/start-builder.sh first.\n' >&2
    exit 1
fi
if ! command -v rsync >/dev/null 2>&1; then
    printf 'Required host tool not found: rsync\n' >&2
    exit 1
fi

mkdir -p "$destination"
rsync --archive --compress \
    -e "ssh -i $runtime/id_ed25519 -p $port -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$known_hosts" \
    "builder@127.0.0.1:$remote_path" "$destination/"
printf 'Fetched builder output into %s\n' "$destination"
