#!/usr/bin/bash
# Root entry point inside the disposable GUI-test container. Real desktops
# already provide these system services through systemd.
set -euo pipefail
install -d /run/dbus
dbus-daemon --system --fork
/usr/lib/polkit-1/polkitd --no-debug &
for attempt in {1..30}; do
    if busctl --system status org.freedesktop.PolicyKit1 >/dev/null 2>&1; then break; fi
    sleep 1
done
/usr/libexec/accounts-daemon &
for attempt in {1..30}; do
    if busctl --system status org.freedesktop.Accounts >/dev/null 2>&1; then break; fi
    sleep 1
done
exec runuser -u flatpak-test -- dbus-run-session -- check-flatpak-desktop
