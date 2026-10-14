# bootc-gnome

A minimal Fedora bootc desktop with GNOME components installed individually. The image does **not** install Fedora's Workstation package group.

## Image contents

The Containerfile explicitly installs GDM, GNOME Shell/session/settings, a terminal, a text editor, Files, Wi-Fi support, and user-directory defaults. Add packages to that list when you want additional desktop applications; there is no Workstation bundle that pulls them in implicitly.

The image uses Fedora's `fedora-bootc:latest` base (latest stable Fedora bootc release) and enables GDM and NetworkManager.

## Build locally

Requirements: Podman and an internet connection.

```sh
./scripts/build-image.sh
```

This builds `localhost/bootc-gnome:local` and always refreshes the Fedora base image. You can choose another local tag:

```sh
./scripts/build-image.sh localhost/bootc-gnome:test
```

### Test in a VM

Build a qcow2 disk with bootc-image-builder from the local image. Rootful Podman is used here so the image builder can access the local image store:

```sh
sudo podman build --pull=always -t localhost/bootc-gnome:local -f Containerfile .
mkdir -p output
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 --rootfs btrfs localhost/bootc-gnome:local
```

Boot the generated `output/qcow2/disk.qcow2` in your preferred VM manager. For example, with libvirt, create a UEFI VM and attach that disk.

## Publish and update

The `Build and publish bootc image` workflow runs every five minutes (GitHub Actions' minimum scheduled interval) and on pushes to `main`. It publishes:

- `ghcr.io/eth0lo/bootc-gnome:stable` — moving update channel
- `ghcr.io/eth0lo/bootc-gnome:sha-<commit>` — immutable build reference

The repository must have **Settings → Actions → General → Workflow permissions** set to allow the `GITHUB_TOKEN` to write packages. Make the GHCR package public for clients to pull without authentication.

Installed clients can switch to the image and update with:

```sh
sudo bootc switch ghcr.io/eth0lo/bootc-gnome:stable
sudo bootc upgrade
```

## Build an installer ISO

The `Build installer ISO` workflow is manual: use **Actions → Build installer ISO → Run workflow**. It pulls the latest `stable` image, uploads the Anaconda installer ISO and SHA-256 checksum as a 30-day Actions artifact, and publishes them to GHCR as the `bootc-gnome-iso` package. The package appears in the repository's **Packages** sidebar and keeps a version tagged `iso-<date>-<run-number>`.

Download the package contents with [ORAS](https://oras.land/):

```sh
oras pull ghcr.io/eth0lo/bootc-gnome-iso:iso-<date>-<run-number>
```

The Actions artifact is also available from the completed workflow run's **Artifacts** section.

For a local ISO build from the published image:

```sh
./scripts/build-iso.sh
```

The generated ISO is `output/bootiso/install.iso`. To build from a different image reference, pass it as an argument:

```sh
./scripts/build-iso.sh ghcr.io/eth0lo/bootc-gnome:sha-<commit>
```
