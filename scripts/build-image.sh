#!/usr/bin/env bash
set -euo pipefail

image="${1:-localhost/bootc-gnome:local}"

if [[ "$(id -u)" -eq 0 ]]; then
    container_engine=(podman)
else
    container_engine=(sudo podman)
fi

"${container_engine[@]}" build \
    --pull=always \
    --network=host \
    --tag "$image" \
    --file Containerfile .
printf 'Built %s\n' "$image"
