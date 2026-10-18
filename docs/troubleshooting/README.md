# Troubleshooting history

These notes record boot, first-user, and update-authorization problems found
during development, along with their diagnosis, resolution, and verification.
The files are numbered in the order the issues arose. The first issues date
from development of the Fedora 43 image; the current local image is Fedora 44.

1. [Locale picker had no available locales](01-locale-picker.md) — add the
   English glibc locale data.
2. [The root filesystem was remounted as Btrfs at boot](02-systemd-remount-fs.md)
   — remove Anaconda's incorrect `/` fstab entry during installation.
3. [The first user's home directory was missing](03-missing-home-directory.md)
   — provision `/var/home` and enable PAM/oddjob home creation.
4. [GNOME Software asked for credentials to check updates](04-update-authentication-prompt.md)
   — historical rpm-ostree refresh authorization workaround, now superseded by
   removing GNOME Software and using bootc for OS updates. See [ADR 0001](../adr/0001-bootc-sole-os-update-path.md).

## Current outcome

- The image and ISO include the locale and home-directory changes.
- A fresh VM boot was reported to work without the missing-home error.
- The former update-check workaround has been superseded; bootc is the supported
  OS-update path.
- The fstab workaround is embedded in the rebuilt installer ISO; see the
  [fstab troubleshooting note](02-systemd-remount-fs.md) for verification.
