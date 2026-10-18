# bootc-gnome

A Fedora bootc desktop using a selected set of GNOME-related groups. The image does **not** install Fedora's Workstation environment.

**[Download the latest installer ISO](https://archive.org/download/bootc-gnome/bootc-gnome.iso)**

## Image contents

The Containerfile uses selected Fedora 44 groups documented in `FEDORA-44-GROUPS.md`. GNOME desktop and multimedia groups are expanded into their Fedora 44 comps package selections so GNOME Software and its OS-update integrations are not installed. PackageKit's daemon is excluded from weak dependencies; `PackageKit-glib` remains because GNOME Document Scanner (`simple-scan`) requires the client library. The image retains Flatpak and fwupd command-line support. It does not install the Workstation environment, Firefox, or LibreOffice. `networkmanager-submodules` supplies NetworkManager's Wi-Fi, Bluetooth, and WWAN modules. GNOME Initial Setup prompts you to create the first user account. `domain-client` supplies domain and Samba/Winbind tools as well as `oddjob-mkhomedir`; authselect's `with-mkhomedir` feature and `oddjobd.service` are enabled so the first login creates the user's home under `/var/home`. The image also includes GDM and the English locale.

The local development image is pinned to Fedora 44 so its group contents match the documented selection. These local changes are still under development; the published GHCR image remains the last pushed build.

## Build locally

Requirements: Podman, sudo access, and an internet connection. The helper builds with rootful Podman so bootc-image-builder can use the same local image store.

```sh
./scripts/build-image.sh
```

This builds `localhost/bootc-gnome:local` from the local Containerfile and refreshes the Fedora 44 base image. You can choose another local tag:

```sh
./scripts/build-image.sh localhost/bootc-gnome:test
```

### Test the container image in a VM

Build a QCOW2 disk from the local image:

```sh
./scripts/build-qcow2.sh
```

Boot the generated `output/qcow2/disk.qcow2` in your preferred VM manager. For example, with libvirt, create a UEFI VM and attach that disk.

### Build a local installer ISO

After the image has been tested, build an Anaconda installer ISO from the local image. `iso-config.toml` removes the root entry Anaconda writes into `/etc/fstab`; bootc uses a read-only composefs overlay for `/`, so remounting that root as Btrfs causes `systemd-remount-fs.service` to fail.

```sh
./scripts/build-iso.sh
```

The ISO is written to `output/bootiso/install.iso`. Both local image-builder scripts accept an image reference as their first argument.

## Publish and update

The `Build and publish bootc image` workflow runs daily at 06:17 UTC and on every push to `main` (including merges). It publishes:

- `ghcr.io/eth0lo/bootc-gnome:stable` — moving update channel
- `ghcr.io/eth0lo/bootc-gnome:sha-<commit>` — immutable build reference

The repository must have **Settings → Actions → General → Workflow permissions** set to allow the `GITHUB_TOKEN` to write packages. Make the GHCR package public for clients to pull without authentication.

Installed clients can switch to the image and update with:

```sh
sudo bootc switch ghcr.io/eth0lo/bootc-gnome:stable
sudo bootc upgrade
```

Bootc is the supported path for operating-system updates. Use `flatpak` to
manage Flatpak applications and `fwupdmgr` to manage supported device firmware;
neither replaces bootc for updating the operating system.

## Build an installer ISO

The `Build installer ISO` workflow runs on the first of each month at 06:00 UTC and can also be started manually from **Actions → Build installer ISO → Run workflow**. It builds an installer from the latest `stable` image, uploads the ISO and SHA-256 checksum as a 30-day Actions artifact, and overwrites the same files in the public Internet Archive item.

The workflow uses the repository Actions secrets `IA_ACCESS_KEY_ID` and `IA_SECRET_ACCESS_KEY`, created from the account's Internet Archive S3 keys.

- [Download the installer ISO](https://archive.org/download/bootc-gnome/bootc-gnome.iso)
- [Download its SHA-256 checksum](https://archive.org/download/bootc-gnome/bootc-gnome.iso.sha256)

After downloading both files into the same directory, verify the ISO with `sha256sum -c bootc-gnome.iso.sha256`. The workflow removes the previous Archive.org files without keeping backups, then uploads the new ISO and checksum to the same stable URLs. The Actions artifact is also available from the completed workflow run's **Artifacts** section for 30 days.
