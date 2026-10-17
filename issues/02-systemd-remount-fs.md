# 2. The root filesystem was remounted as Btrfs at boot

## Symptom

`systemd-remount-fs.service` failed on every boot. The generated installer
system's `/etc/fstab` contained a Btrfs mount entry for `/`, and systemd tried
to remount the bootc root filesystem using that entry.

## Cause

The root filesystem in this bootc image is composefs-backed; it is not a
regular Btrfs root mount. Anaconda's generated root fstab entry therefore
described a remount that was invalid for the installed system.

## Resolution

Added [`iso-config.toml`](../iso-config.toml) with a kickstart `%post` step
that removes only entries whose mountpoint field is `/` from `/etc/fstab`:

```kickstart
%post --erroronfail
awk 'NF == 0 || $1 ~ /^#/ || $2 != "/"' /etc/fstab > /etc/fstab-new
mv /etc/fstab-new /etc/fstab
%end
```

The local ISO build script mounts this config into bootc-image-builder, and
the workaround is applied during installation rather than by changing the
immutable root mount after boot. Unlike the first version of the filter, this
preserves comments and every non-root entry, including `/boot/efi`, swap, and
user-created mountpoints.

## Verification and status

The rebuilt ISO was verified to contain this kickstart content and to include
BIOS and UEFI boot entries. The workaround is present in the current local
installer ISO. A separate user confirmation of this service's status after a
fresh install was not recorded.
