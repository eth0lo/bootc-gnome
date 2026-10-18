#!/usr/bin/env bash
# Make a virtual hard drive with this desktop operating system already
# installed.
#
# Choose the resulting file as a VM's hard drive in QEMU, virt-manager,
# or GNOME Boxes, then start the VM to boot this system.
#
# This IS NOT an installer ISO; it boots the installed system directly.
#
# Before running this script, build the operating-system image:
#   ./scripts/build-image.sh
#
# Then create a disk from the default image:
#   ./scripts/build-qcow2.sh
#
# If you gave the image a different name, use that same name here:
#   ./scripts/build-image.sh localhost/bootc-gnome:test
#   ./scripts/build-qcow2.sh localhost/bootc-gnome:test
#
# OUTPUT: The disk is saved as output/qcow2/disk.qcow2.
#
# USAGE: Open it with a virtual-machine program such as QEMU,
#        GNOME Boxes, or virt-manager.
#
# NOTE: Building directly on your computer may ask for your sudo password.
#       Running this script inside the project's builder VM does not ask
#       for a password.
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

if ! "${container_engine[@]}" image exists "$image"; then
    printf 'Local image %s not found; run ./scripts/build-image.sh first\n' "$image" >&2
    exit 1
fi

"${container_engine[@]}" run \
    --rm \
    --privileged \
    --security-opt label=type:unconfined_t \
    -v "$PWD/output:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --rootfs btrfs \
    "$image"

if [[ "$(id -u)" -ne 0 ]]; then
    sudo chown -R "$output_owner" output
fi

printf 'QCOW2 output: %s/output/qcow2/disk.qcow2\n' "$PWD"
