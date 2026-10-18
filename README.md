# bootc-gnome

A Fedora bootc desktop using a selected set of GNOME-related groups. The image does **not** install Fedora's Workstation environment.

**[Download the latest installer ISO](https://archive.org/download/bootc-gnome/bootc-gnome.iso)**

## Image contents

The Containerfile uses selected Fedora 44 groups documented in `FEDORA-44-GROUPS.md`. GNOME desktop and multimedia groups are expanded into their Fedora 44 comps package selections so GNOME Software and its OS-update integrations are not installed. PackageKit's daemon is excluded from weak dependencies; `PackageKit-glib` remains because GNOME Document Scanner (`simple-scan`) requires the client library. The image includes native Bazaar for Flatpak applications, system-wide Apostrophe, and fwupd command-line support. It does not install the Workstation environment, Firefox, or LibreOffice. `networkmanager-submodules` supplies NetworkManager's Wi-Fi, Bluetooth, and WWAN modules. GNOME Initial Setup prompts you to create the first user account. `domain-client` supplies domain and Samba/Winbind tools as well as `oddjob-mkhomedir`; authselect's `with-mkhomedir` feature and `oddjobd.service` are enabled so the first login creates the user's home under `/var/home`. The image also includes GDM and the English locale.

See the [troubleshooting notes](docs/troubleshooting/README.md) for development
history and [ADR 0001](docs/adr/0001-bootc-sole-os-update-path.md) for the
operating-system update policy and its trade-offs.

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

### Flatpak applications

Bazaar is a native, image-managed application: bootc updates the store itself,
while Bazaar manages Flatpak applications rather than operating-system updates.
Its Fedora 44 RPM is pinned to Universal Blue's `0.9.3-4.fc44` build from the
`ublue-os/packages` COPR, matching Bazzite's published Fedora 44 stable version.
The repository is disabled by default and restricted to the `bazaar` package;
RPM signature checking is enabled and Fedora supplies dependencies. Bazaar is
built by Universal Blue from upstream release source without downstream source
patches ([Fedora 44 package spec](https://download.copr.fedorainfracloud.org/results/ublue-os/packages/fedora-44-x86_64/10856688-bazaar/bazaar.spec)).
The package's hardcoded configuration paths are provided by this image;
the base image defines no extra content rows, recommendations, or transaction
hooks.

Each account gets an enabled user Flathub remote before Bazaar's daemon starts.
A user service also configures new accounts at login and repairs the remote
every two minutes. The definition and signing key are carried in the image, so
configuration does not need networking. The system remote is enabled but
non-enumerated: it contributes existing shared applications rather than a second
catalog for installing new apps system-wide. Fedora's remote-creation service is
masked. A second system remote, `flathub-runtimes`, points to the same signed
Flathub repository with a runtime-only filter. It allows Flatpak to resolve new
runtime branches during system-app updates without offering system app installs.
The ISO desktop harness verifies the selected package's ordinary Get/Install
path selects user scope; see the [Flatpak acceptance checks](tests/flatpak/README.md)
for coverage and additional UI entry points.

`org.gnome.gitlab.somas.Apostrophe` is the first shared default. Its stable app
and required runtime/extensions are installed under `/var/lib/flatpak` during
image composition, so fresh installations carry the payload offline. Optional
TeXLive is not selected. App/runtime refs follow Flathub stable at composition
time; the image records their refs and resolved commit prefixes in
`/usr/share/bootc-gnome/flatpak-build-refs.txt`. The Flathub repository definition
is checksum-verified; a deliberate checksum update is needed if its contents or
signing key change.

Bootc initializes `/var` on a fresh install, but does not synchronize it on
upgrades. To introduce another shared app, add its stable Flathub ID to
`files/usr/share/bootc-gnome/flatpak-defaults`. The provisioning timer offers
delivery five minutes after boot and every fifteen minutes afterward, with a
random delay. Downloads require a known-unmetered NetworkManager connection.
Only NetworkManager's explicit `NO` state qualifies; `GUESS_NO`, `YES`,
`GUESS_YES`, unavailable, and unknown states defer delivery.
Runtime dependencies come from the runtime-only Flathub view. A failing app does
not block other pending defaults; failures remain retryable.

Successful delivery is recorded per app in `/var/lib/bootc-gnome-flatpaks`,
including apps seeded in the image. Removing an app later is respected across
reboots, upgrades, and rollbacks. Removing its manifest entry does not uninstall
it. The provisioner does not update already-delivered apps: their lifecycle is
Flatpak-managed, independently of bootc. Standard Bazaar behavior governs user
application downloads and updates.

Useful diagnostics:

```sh
flatpak list --system
flatpak list --user
flatpak remotes --system --show-details
flatpak remotes --user --show-details
journalctl -u bootc-gnome-flatpak-defaults.service
systemctl --user status bootc-gnome-flathub.timer
```

### Disposable builder VM

For image-builder work without granting build privileges to the host, the
repository includes scripts to prepare and run an official Fedora Cloud VM.
Cloud-init installs the build tools, creates a passwordless-sudo `builder`
account inside the guest, and authorizes a runtime SSH key. No password or
private key is baked into the guest image.

Build the VM disk, start it, then open an SSH session:

```sh
./scripts/prepare-builder.sh
./scripts/start-builder.sh
./scripts/builder-sync.sh
./scripts/builder-exec.sh bash -lc 'cd ~/bootc-gnome && ./scripts/build-image.sh'
```

Rootful Podman and bootc-image-builder run inside the VM. On the host,
`prepare-builder.sh` needs only `curl`, `qemu-img`, `xorriso`, `ssh-keygen`,
Python 3, and KVM access; `start-builder.sh` additionally needs QEMU, OVMF,
and OpenSSH. The VM uses QEMU user networking and exposes SSH only on host
loopback port 2222; set `BUILDER_SSH_PORT` to choose another port. Use
`scripts/builder-exec.sh COMMAND ...` for noninteractive commands,
`scripts/builder-fetch.sh` to retrieve artifacts, and
`scripts/stop-builder.sh` for graceful shutdown. The working disk, runtime
key, seed, and logs live under ignored `output/builder/`. The guest's working
disk persists between starts; `scripts/builder-sync.sh` copies the current
checkout into the guest (excluding generated `output/` artifacts). See
[`builder/README.md`](builder/README.md) for details.

After preparing the builder, run `./scripts/test-boot.sh` to build a temporary
test image and verify its first boot, desktop services, and staged-update unit
configuration. See [`tests/README.md`](tests/README.md) for checks and evidence.

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

Published installer images track the `stable` channel. Local image-builder
scripts continue to preserve the image reference supplied to them, so test
installations can track a local or other explicitly selected image.

The image stages OS updates automatically without restarting the computer.
Checks are offered every two hours, with randomized delay; successful checks
are limited to one per day. Failed checks and checks deferred because the
connection is metered or its metering state is unknown are retried at the next
timer opportunity. Automatic checks run at low CPU and disk priority and do not
wait for a user session. A staged update is activated on the next normal reboot.

Inspect the schedule and staged deployment with:

```sh
systemctl status bootc-fetch-apply-updates.timer
journalctl -u bootc-fetch-apply-updates.service
sudo bootc status
```

Installed clients can switch to the image and manually check for updates with:

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
