#!/usr/bin/env bash
set -euo pipefail

image="${1:-localhost/bootc-gnome:local}"
mkdir -p output

if [[ "$(id -u)" -eq 0 ]]; then
    container_engine=(podman)
    output_owner="0:0"
else
    container_engine=(sudo podman)
    output_owner="$(id -u):$(id -g)"
fi

if [[ "$image" == localhost/* ]]; then
    if ! "${container_engine[@]}" image exists "$image"; then
        printf 'Local image %s not found; run ./scripts/build-image.sh first\n' "$image" >&2
        exit 1
    fi
else
    "${container_engine[@]}" pull "$image"
fi

"${container_engine[@]}" run \
    --rm \
    --privileged \
    --security-opt label=type:unconfined_t \
    -v "$PWD/output:/output" \
    -v "$PWD/iso-config.toml:/config.toml:ro" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type anaconda-iso \
    --rootfs btrfs \
    "$image"

if [[ "$(id -u)" -ne 0 ]]; then
    sudo chown -R "$output_owner" output
fi

printf 'ISO output: %s/output/bootiso/install.iso\n' "$PWD"
