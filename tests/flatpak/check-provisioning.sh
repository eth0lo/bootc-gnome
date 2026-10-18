#!/usr/bin/bash
# Online, disposable-container integration test: exercise actual Flathub refs
# from an empty installation, rather than mocking Flatpak dependency behavior.
set -euo pipefail
export FLATPAK_SYSTEM_DIR="$(mktemp -d)"
state="$(mktemp -d)"
trap 'rm -rf "$FLATPAK_SYSTEM_DIR" "$state"' EXIT
export PATH="$(dirname "$0")/bin:$PATH"

/usr/libexec/bootc-gnome-flathub system
/usr/libexec/bootc-gnome-flatpak-defaults --state-dir "$state"
flatpak info --system org.gnome.gitlab.somas.Apostrophe//stable
flatpak uninstall --system --noninteractive --assumeyes org.gnome.gitlab.somas.Apostrophe
/usr/libexec/bootc-gnome-flatpak-defaults --state-dir "$state"
if flatpak info --system org.gnome.gitlab.somas.Apostrophe//stable; then
    printf 'FAIL: user-removed Apostrophe was reinstalled\n' >&2
    exit 1
fi
printf 'PASS: real non-enumerated Flathub provisioning, runtime delivery, and removal respect\n'
