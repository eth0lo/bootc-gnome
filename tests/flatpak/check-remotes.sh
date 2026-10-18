#!/usr/bin/bash
# Run inside a disposable image container; do not run on an installed desktop.
set -euo pipefail

export HOME="$(mktemp -d)"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
trap 'rm -rf "$HOME"' EXIT

/usr/libexec/bootc-gnome-flathub user
[[ "$(flatpak remotes --user --columns=name)" == flathub ]]

# An image's changed definition/key must be applied even when all remote
# properties already match. Simulate a previous image's digest and lost key.
keyring="$XDG_DATA_HOME/flatpak/repo/flathub.trustedkeys.gpg"
[[ -s "$keyring" ]]
rm "$keyring"
printf 'previous-image-definition' > "$XDG_CACHE_HOME/flathub.definition"
/usr/libexec/bootc-gnome-flathub user
[[ -s "$keyring" ]]
[[ "$(flatpak remotes --user --columns=options)" != *no-enumerate* ]]
flatpak remote-modify --user --disable flathub
/usr/libexec/bootc-gnome-flathub user
[[ "$(flatpak remotes --user --columns=name,options)" != *disabled* ]]
flatpak remote-delete --user flathub
/usr/libexec/bootc-gnome-flathub user
[[ "$(flatpak remotes --user --columns=name)" == flathub ]]

flatpak remote-modify --system --disable --enumerate flathub
/usr/libexec/bootc-gnome-flathub system
[[ "$(flatpak remotes --system --columns=name,options)" == *no-enumerate* ]]
[[ "$(flatpak remotes --system --columns=name,options)" != *disabled* ]]
[[ "$(flatpak remotes --system --columns=name)" == *flathub-runtimes* ]]
flatpak info --system org.gnome.gitlab.somas.Apostrophe//stable
printf 'PASS: offline remote initialization, deletion recovery, and policy repair\n'
