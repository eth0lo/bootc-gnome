# Fedora 43 GNOME group selection

This document records a small Fedora 43 package-group selection for a GNOME
system. It uses Fedora comps groups rather than listing individual packages.
The group definitions were gathered from the [Fedora 43 Everything repository
comps metadata](https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Everything/x86_64/os/repodata/73a6103e51d00abd1abd50eb54f98a07b398a86972555b532af6acdb98565c3d-comps-Everything.x86_64.xml.zst).

## Groups

| Group ID | Purpose |
| --- | --- |
| `core` | Core operating-system packages. |
| `base-graphical` | Base graphical-system components. |
| `gnome-desktop` | GNOME desktop environment and its required/default applications. |
| `domain-client` | Domain membership tools, including `oddjob-mkhomedir`, SSSD clients, and Samba/Winbind utilities. |
| `hardware-support` | General hardware support. |
| `printing` | Printing support. |
| `multimedia` | Multimedia support. |

Install the groups with DNF:

```sh
sudo dnf -y group install \
    core \
    base-graphical \
    gnome-desktop \
    domain-client \
    hardware-support \
    printing \
    multimedia
```

This selection does not install the separate `firefox` or `libreoffice` groups.
For reproducible results, use Fedora 43 repositories when installing these
groups; group contents can change between Fedora releases.

`gnome-desktop` includes `gnome-initial-setup`; do not install it a second time
as an explicit package. `domain-client` includes `oddjob-mkhomedir`, but the
image must also enable authselect's `with-mkhomedir` feature and the
`oddjobd.service` for PAM to create home directories on first login.

The Fedora 43 `domain-client` group also installs `adcli`, `freeipa-client`,
`samba-common-tools`, `samba-winbind`, `sssd-ad`, and `sssd-ipa` as mandatory
packages. Its default packages are `libsss_autofs`, `libsss_sudo`, and
`sssd-nfs-idmap`.

## OSTree support group

The separate `workstation-ostree-support` group provides OSTree-related
packages, including `nss-altfiles`, `ostree-grub2` on supported architectures,
and `rpm-ostree`. Installing it does not convert an image to Silverblue or
configure it as an immutable OSTree desktop. Fedora bootc images use bootc's
image-based update model; adding this group does not change that model.
