#!/usr/bin/env bash
# Make an installer file for the desktop operating system.
#
# Start a VM or computer from this file to install the operating system there.
# This is installation media; it is not a virtual-machine hard drive.
#
# Before running this script, build the operating-system image:
#   ./scripts/build-image.sh
#
# Create an ISO from the default image:
#   ./scripts/build-iso.sh
#
# If you gave the image a different name, use that same name here:
#   ./scripts/build-image.sh localhost/bootc-gnome:test
#   ./scripts/build-iso.sh localhost/bootc-gnome:test
#
# Or download the published stable image and make an installer from it:
#   ./scripts/build-iso.sh ghcr.io/eth0lo/bootc-gnome:stable
# Published images are downloaded automatically. An image whose name starts
# with localhost/ must already have been built on this computer.
#
# DEFAULT IMAGE NAME: localhost/bootc-gnome:local
#
# OUTPUT: output/bootiso/install.iso
#
# NOTE: Running this script on your computer may ask for your sudo password.
#       Running it inside the project's builder VM does not ask for a password.
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
