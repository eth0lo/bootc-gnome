# Fedora 44 GNOME group selection

This document records the Fedora 44 comps groups and package selections used
for a GNOME system. GNOME and multimedia group contents are expanded in the
Containerfile so specific applications and update integrations can be omitted;
the full compositions, with package types and exclusions, are recorded beside
their explicit package lists. The group definitions were gathered from the [Fedora 44 Everything repository
comps metadata](https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/repodata/6a37d36914955dc65cf6dc037c37dcf00c64ded464dc34164a674bf65fa16927-comps-Everything.x86_64.xml.zst).

## Groups

| Group ID | Purpose |
| --- | --- |
| `core` | Core operating-system packages. |
| `base-graphical` | Base graphical-system components. |
| `gnome-desktop` | GNOME desktop environment and its required/default applications. |
| `networkmanager-submodules` | Common NetworkManager modules for Wi-Fi, Bluetooth, and WWAN, plus `dnsmasq`, `iptables-nft`, and `wpa_supplicant`. |
| `domain-client` | Domain membership tools, including `oddjob-mkhomedir`, SSSD clients, and Samba/Winbind utilities. |
| `hardware-support` | General hardware support. |
| `printing` | Printing support. |
| `multimedia` | Multimedia support. |

The Containerfile continues to install these unexpanded groups with DNF:

```sh
sudo dnf -y group install \
    core \
    base-graphical \
    networkmanager-submodules \
    domain-client \
    hardware-support \
    printing
```

The Fedora 44 `gnome-desktop` group was expanded and its `gnome-software`,
`PackageKit-command-not-found`, and `PackageKit-gtk3-module` entries omitted.
The `multimedia` group's `PackageKit-gstreamer-plugin` entry was omitted, and
its conditional `gstreamer-plugins-espeak` package is installed only when its
`gstreamer` condition is met. The complete selected compositions at expansion
time are documented in comments in `Containerfile`.

The PackageKit daemon is excluded from weak dependencies, including the
recommendation from the printer-configuration libraries, while printing
support remains installed. `PackageKit-glib` is intentionally retained because
`simple-scan` requires it; the library is not the PackageKit OS-update daemon.
Flatpak and fwupd are explicit packages. bootc remains the supported operating-
system update path.

This selection does not install the separate `firefox` or `libreoffice` groups.
For reproducible results, use Fedora 44 repositories when installing these
groups; group contents can change between Fedora releases.

`gnome-desktop` includes `gnome-initial-setup`; do not install it a second time
as an explicit package. `domain-client` includes `oddjob-mkhomedir`, but the
image must also enable authselect's `with-mkhomedir` feature and the
`oddjobd.service` for PAM to create home directories on first login.

`core` installs `NetworkManager` by default. `networkmanager-submodules` adds
`NetworkManager-bluetooth`, `NetworkManager-wifi`, `NetworkManager-wwan`,
`dnsmasq`, `iptables-nft`, and `wpa_supplicant` as default packages, so the
Wi-Fi module does not need to be listed as a separate package.

The Fedora 44 `domain-client` group also installs `adcli`, `freeipa-client`,
`samba-common-tools`, `samba-winbind`, `sssd-ad`, and `sssd-ipa` as mandatory
packages. Its default packages are `libsss_autofs`, `libsss_sudo`, and
`sssd-nfs-idmap`.

## OSTree support group

The separate `workstation-ostree-support` group provides OSTree-related
packages, including `nss-altfiles`, `ostree-grub2` on supported architectures,
and `rpm-ostree`. Installing it does not convert an image to Silverblue or
configure it as an immutable OSTree desktop. Fedora bootc images use bootc's
image-based update model; adding this group does not change that model.
