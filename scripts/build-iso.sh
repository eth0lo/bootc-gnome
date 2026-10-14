#!/usr/bin/env bash
set -euo pipefail

image="${1:-ghcr.io/eth0lo/bootc-gnome:stable}"
mkdir -p output

if [[ "$(id -u)" -eq 0 ]]; then
    container_engine=(podman)
else
    container_engine=(sudo podman)
fi

"${container_engine[@]}" pull "$image"
"${container_engine[@]}" run \
    --rm \
    --privileged \
    --security-opt label=type:unconfined_t \
    -v "$PWD/output:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type anaconda-iso \
    --rootfs btrfs \
    "$image"

printf 'ISO output: %s/output/bootiso/install.iso\n' "$PWD"
