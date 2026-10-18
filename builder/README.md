# Local Fedora builder VM

The builder is a disposable Fedora Cloud Base virtual machine. The host
downloads Fedora's official Fedora 44 QCOW2 image, verifies its pinned SHA-256,
and creates a writable QCOW2 overlay. Cloud-init installs build tools and
creates a `builder` account with passwordless sudo **inside the guest**.

No privileged image build is required on the host. QEMU runs as the current
user with KVM, and SSH is forwarded only to host loopback. The guest receives
an ephemeral public key through a local NoCloud seed; the private key remains
on the host under ignored `output/builder/runtime/`.

```sh
./scripts/prepare-builder.sh
./scripts/start-builder.sh
./scripts/builder-sync.sh
./scripts/builder-exec.sh bash -lc 'cd ~/bootc-gnome && ./scripts/build-image.sh'
./scripts/builder-exec.sh bash -lc 'cd ~/bootc-gnome && ./scripts/build-qcow2.sh'
./scripts/builder-fetch.sh
./scripts/stop-builder.sh
```

Preparation pins Fedora Cloud Base Generic 44.1.7 and a 120 GiB virtual disk.
The qcow2 disk is sparse. The downloaded base is cached separately and never
modified. Preparation reuses an existing working disk and credentials; it
does not reset or replace them.

Host requirements: QEMU x86-64 with KVM access, `qemu-img`, OVMF firmware,
`xorriso`, `curl`, Python 3, OpenSSH client utilities, `rsync`, and coreutils.
The default VM uses four vCPUs, 8 GiB memory, and SSH host port 2222. Override
these with `BUILDER_CPUS`, `BUILDER_MEMORY_MB`, and `BUILDER_SSH_PORT`.

The guest uses QEMU user-mode networking rather than a host bridge. It can
reach the host via `10.0.2.2`, and the host can reach guest SSH through
`127.0.0.1:2222`. Generated builder disk, cloud-init seed, keys, and logs live
under ignored `output/builder/`. The generated desktop QCOW2 is copied back
under `output/builder/guest-output/`.

The Fedora image download is verified against the SHA-256 published in Fedora's
signed [44.1.7 Cloud CHECKSUM](https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-44-1.7-x86_64-CHECKSUM). The image itself is
from [Fedora's Cloud image directory](https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/).
