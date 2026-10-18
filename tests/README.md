# Local boot test

Run the first-boot smoke test from the project folder:

```sh
./scripts/test-boot.sh
```

The script builds the current desktop image inside the Fedora builder VM, then
adds a test-only account and SSH key, builds a QCOW2 disk, and boots that disk
on the host with QEMU/KVM and UEFI. The SSH account and key exist only in this
test image; they are not added to the production `Containerfile` or published
image.

The test waits for SSH, then verifies that:

- The VM booted the exact image built for this run.
- `graphical.target` and `gdm.service` are active.
- Systemd reports no failed units.
- The update timer is enabled.
- The effective update service runs
  `/usr/libexec/bootc-gnome-upgrade` without `--apply`.
- Native Bazaar, seeded system Apostrophe, its delivery record, and the
  non-enumerated system Flathub configuration survive installation.
- Fedora's Flatpak remote-creation service is masked and the system Flatpak
  delivery timer is enabled.

This is a headless boot check: it verifies that GDM and the graphical systemd
target are active, not that a person can see or interact with the login screen.
It does not stage an update, reboot into one, or test rollback.

The [Flatpak lifecycle tests](flatpak/README.md) additionally cover remote repair,
delivery/retry history, a real signed Apostrophe runtime transition, and actual
offline Anaconda installation with GNOME app workflows. They also provide an
online overlay test of Bazaar's normal per-user Get/Install path.

## Requirements

- Prepare the local Fedora builder VM using `builder/README.md`.
- Host QEMU with KVM access, OVMF firmware, `qemu-img`, SSH tools, and `timeout`.
- Network access for the builder to pull base/package images when they are not
  already cached.
- The default test SSH port, `2233`, must be available. Override it with
  `BOOT_TEST_SSH_PORT`; the VM defaults are 4 CPUs and 6 GiB RAM, configurable
  with `BOOT_TEST_CPUS` and `BOOT_TEST_MEMORY_MB`.

The harness starts and stops the builder VM only if it started it. If the
builder was already running, it leaves it running. Test QCOW2 files, temporary
SSH keys, serial output, effective unit files, and health results are retained
under the ignored `output/boot-tests/<run-id>/` directory.

An exit status of zero means every boot assertion passed. On failure, review
`health-check.txt`, `bootc-status.txt`, `update-units.txt` (effective settings),
`unit-files.txt` (vendor units and drop-ins), `failed-units.txt`, `journal.txt`,
`serial.log`, and `qemu.log` in the run's output directory.
