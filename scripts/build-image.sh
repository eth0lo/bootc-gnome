#!/usr/bin/env bash
set -euo pipefail

image="${1:-localhost/bootc-gnome:local}"
podman build --pull=always --tag "$image" --file Containerfile .
printf 'Built %s\n' "$image"
