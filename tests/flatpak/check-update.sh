#!/usr/bin/bash
# Online, disposable-container test of a real signed Apostrophe update across
# runtime branches. This tests Flatpak transactions, not Bazaar's update UI.
set -euo pipefail
export FLATPAK_SYSTEM_DIR="$(mktemp -d)"
export HOME="$(mktemp -d)"
trap 'rm -rf "$FLATPAK_SYSTEM_DIR" "$HOME"' EXIT
app=org.gnome.gitlab.somas.Apostrophe
old=522ff389b5bf48c4fc4f825ba1c9a7cab797d23f851e2d777db0db9339b1817c
/usr/libexec/bootc-gnome-flathub system
[[ -z "$(flatpak remote-ls --system --app flathub-runtimes)" ]]
flatpak install --system --assumeyes --noninteractive flathub "$app//stable"
current_runtime="$(flatpak info --system --show-runtime "$app")"
flatpak update --system --assumeyes --noninteractive --commit="$old" "$app"
[[ "$(flatpak info --system --show-runtime "$app")" == org.gnome.Platform/x86_64/49 ]]
[[ "$(flatpak info --system --show-commit "$app")" == "$old" ]]
flatpak uninstall --system --assumeyes --noninteractive "runtime/$current_runtime"
if flatpak info --system "runtime/$current_runtime"; then
    printf 'FAIL: newer runtime is still installed\n' >&2
    exit 1
fi
flatpak update --system --assumeyes --noninteractive "$app"
[[ "$(flatpak info --system --show-runtime "$app")" == "$current_runtime" ]]
[[ "$(flatpak info --system --show-commit "$app")" != "$old" ]]
flatpak info --system "runtime/$current_runtime"
printf 'PASS: signed Apostrophe update automatically resolves its new system runtime\n'
