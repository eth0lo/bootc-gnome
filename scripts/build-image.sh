#!/usr/bin/env bash
# Build the desktop operating system in a form the other build scripts can use.
#
# The result is a packaged copy of the operating system, called a container
# image. Podman stores it on this computer. It is not a disk you can boot.
# Use it to create a virtual-machine disk or an installer ISO.
#
# Before running this script, change to the main project folder.
#
# Build the default image:
#   ./scripts/build-image.sh
#
# Or give the image a name of your choice, such as `test`:
#   ./scripts/build-image.sh localhost/bootc-gnome:test
#
# DEFAULT IMAGE NAME: localhost/bootc-gnome:local
# If you choose another name, use that same name when creating a VM disk or ISO.
#
# OUTPUT: The image is kept in Podman's local collection; no image file is
# created by this script.
#
# USAGE: Create a VM disk with ./scripts/build-qcow2.sh, or an installer ISO
#        with ./scripts/build-iso.sh.
#
# NOTE: Running this script on your computer may ask for your sudo password.
#       Running it inside the project's builder VM does not ask for a password.
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
