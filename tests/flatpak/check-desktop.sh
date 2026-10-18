#!/usr/bin/bash
# Run as flatpak-test inside a disposable privileged container/VM, without
# networking. Checks real window creation, not just process survival.
set -euo pipefail
export DISPLAY=:99
export GDK_BACKEND=x11
export GSK_RENDERER=cairo
export XDG_RUNTIME_DIR="$(mktemp -d)"
trap 'kill "${xvfb:-}" "${bazaar:-}" "${apostrophe:-}" 2>/dev/null || true' EXIT
Xvfb "$DISPLAY" -screen 0 1280x900x24 > "$XDG_RUNTIME_DIR/xvfb.log" 2>&1 &
xvfb=$!
for attempt in {1..30}; do
    if xdotool getdisplaygeometry >/dev/null 2>&1; then break; fi
    sleep 1
done
dbus-update-activation-environment DISPLAY GDK_BACKEND XDG_RUNTIME_DIR

bazaar-daemon > "$XDG_RUNTIME_DIR/bazaar.log" 2>&1 &
bazaar=$!
if ! timeout 60s xdotool search --sync --onlyvisible --name Bazaar; then
    cat "$XDG_RUNTIME_DIR/bazaar.log"
    exit 1
fi
printf 'PASS: native Bazaar created a window offline\n'

flatpak -v run --system org.gnome.gitlab.somas.Apostrophe > "$XDG_RUNTIME_DIR/apostrophe.log" 2>&1 &
apostrophe=$!
if ! timeout 60s xdotool search --sync --onlyvisible --class Apostrophe; then
    cat "$XDG_RUNTIME_DIR/apostrophe.log"
    exit 1
fi
printf 'PASS: system Apostrophe created a window offline\n'
