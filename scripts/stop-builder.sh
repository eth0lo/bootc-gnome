#!/usr/bin/env bash
# Shut down the builder VM cleanly so its disk is ready for the next start.
# The VM keeps its installed tools, checkout, and built images after shutdown.
#
# Run from any folder:
#   ./scripts/stop-builder.sh
#
# If the guest does not shut down in time, this script stops QEMU so the VM
# does not keep running. It does not delete the VM or its files.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime="$repo_root/output/builder/runtime"
pidfile="$runtime/qemu.pid"
port="${BUILDER_SSH_PORT:-2222}"

if [[ ! -f "$pidfile" ]]; then
    printf 'Builder VM is not running.\n'
    exit 0
fi
pid="$(<"$pidfile")"
if [[ ! "$pid" =~ ^[0-9]+$ ]] || [[ "$(ps -p "$pid" -o args= 2>/dev/null || true)" != *"qemu-system-x86_64"*"-name bootc-builder"* ]]; then
    rm -f "$pidfile"
    printf 'Removed stale builder PID file.\n'
    exit 0
fi

ssh -i "$runtime/id_ed25519" -p "$port" \
    -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$runtime/known_hosts" \
    builder@127.0.0.1 'sudo -n systemctl poweroff' >/dev/null 2>&1 || true

for attempt in {1..60}; do
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$pidfile"
        printf 'Builder VM shut down cleanly.\n'
        exit 0
    fi
    sleep 1
done

printf 'Guest did not power off in time; sending QEMU SIGTERM.\n' >&2
kill "$pid"
for attempt in {1..15}; do
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$pidfile"
        printf 'Builder VM stopped.\n'
        exit 0
    fi
    sleep 1
done
printf 'QEMU process %s is still running.\n' "$pid" >&2
exit 1
