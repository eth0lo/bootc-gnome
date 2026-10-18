# Use bootc as the sole operating-system update path

The image uses bootc as its sole supported operating-system updater, preserving the explicit `sudo bootc upgrade` workflow rather than providing OS updates through GNOME Software and its PackageKit/rpm-ostree integrations. Flatpak applications and supported device firmware remain separately manageable with the `flatpak` and `fwupdmgr` command-line tools; a replacement graphical software center is outside this decision. GNOME Software and the PackageKit daemon are omitted, while `PackageKit-glib` is retained because GNOME Document Scanner (`simple-scan`) requires the client library. Printer support is preserved by excluding the PackageKit daemon as a weak dependency. Automatic update scheduling is not part of this decision.

See the [historical GNOME Software authentication troubleshooting note](../troubleshooting/04-update-authentication-prompt.md).
