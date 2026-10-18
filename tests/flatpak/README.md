# Flatpak lifecycle acceptance

Use Apostrophe (`org.gnome.gitlab.somas.Apostrophe`) for all application-lifecycle
checks. A native Bazaar build and configured remotes are not by themselves proof
that GUI source selection or an offline Anaconda installation works.

## Automated checks

Delivery-state tests, using a simulated Flatpak/NetworkManager command boundary:

```sh
python3 -m unittest discover -s tests/flatpak -v
```

The tests cover metered/unknown/offline deferral, retry after partial installation,
recognition of an existing system app, manifest additions, invalid IDs, and
preserving a user removal. They do not assert GUI or actual runtime behavior.

After building an image inside the builder VM, run the real Flatpak checks in
**disposable containers**, not on an installed desktop. They alter Flatpak state.
Mount this directory at `/tests` with its fixture executable permissions intact:

```sh
sudo podman run --rm --network=none \
  -v "$PWD/tests/flatpak:/tests:ro,z" localhost/bootc-gnome:local \
  bash /tests/check-remotes.sh
sudo podman run --rm \
  -v "$PWD/tests/flatpak:/tests:ro,z" localhost/bootc-gnome:local \
  bash /tests/check-provisioning.sh
sudo podman run --rm \
  -v "$PWD/tests/flatpak:/tests:ro,z" localhost/bootc-gnome:local \
  bash /tests/check-update.sh
```

The first proves configuration and repair work without a network, including
key reimport when upgrading an image-carried definition. The second
creates an empty system installation, uses real Flathub app/runtime downloads
from a non-enumerated remote, and verifies removal is not undone. Only its
NetworkManager response is simulated as unmetered.

The third uses a historical signed Apostrophe commit requiring GNOME runtime 49,
removes the newer runtime, then updates to current stable. It checks that the
runtime-only Flathub source automatically supplies the missing runtime without
exposing an application catalog. The historical commit must remain available on
Flathub for this online test; update the fixture deliberately if it is pruned.

The existing `scripts/test-boot.sh` also checks native Bazaar, system Apostrophe,
its initial delivery record, and system remote policy on a booted QCOW2.

For offline window-creation smoke checks, build a test-only derivative with
Xvfb/xdotool (these tools are not added to production):

```sh
sudo podman build --build-arg BASE_IMAGE=localhost/bootc-gnome:local \
  -f tests/flatpak/Containerfile -t localhost/bootc-gnome:flatpak-desktop-test .
sudo podman run --rm --privileged --network=none \
  localhost/bootc-gnome:flatpak-desktop-test \
  run-flatpak-desktop-test
```

Privileges are confined to the disposable builder VM. Window creation is a smoke
check, not evidence of editing, preview, correct source selection, or ISO delivery.

## Actual offline ISO installation

With a built production ISO available locally:

```sh
python3 tests/flatpak/test-iso.py output/flatpak-iso/install.iso
```

This unattended Anaconda test uses the ISO's kernel, installer and embedded
container, a blank 32 GiB test disk, UEFI, and **no network device during
installation**. A separate OEMDRV disc supplies test-only answers and an
ephemeral SSH key; the production ISO/image is not modified. At first boot,
restricted QEMU networking allows host-forwarded SSH but blocks Internet and
host-service access. A disposable account is automatically logged into GNOME.
The test checks native Bazaar and shared Apostrophe windows, edits and saves
Markdown, activates preview, and reopens the saved document. It verifies saved
bytes and the reopened window; visual inspection of reopened text remains manual
because the GTK accessibility text interface can expose an empty buffer in
preview mode.

Requirements are host QEMU/KVM, OVMF, `qemu-img`, `xorriso`, Python 3, and OpenSSH.
The default SSH port is 2244 (`--port` overrides it). Evidence, disks and the
test-only private key stay under ignored `output/flatpak-iso-tests/<run>/`.
`--resume <run-directory>` rechecks an already installed test disk.

For the ordinary Bazaar installation path, reuse that installation with an
**online disposable disk overlay**:

```sh
python3 tests/flatpak/test-iso.py output/flatpak-iso/install.iso \
  --resume output/flatpak-iso-tests/<run> --online
```

This removes system Apostrophe in the overlay, searches for it in Bazaar,
activates the normal Get/Install controls through accessibility, and verifies the
result is user-only while system Flathub remains non-enumerated. It preserves the
original offline-installed disk. This covers the search-result installation path;
other UI entry points and explicit source-menu visibility still need inspection.

### Additional desktop checks

1. Build the production ISO and install it into a new UEFI VM with its network
   device disconnected. Keep it disconnected through first login.
2. Confirm Bazaar opens. A cold offline Flathub catalog may be unavailable; the
   store must still launch without attempting an OS update.
3. Launch Apostrophe, enter Markdown, open preview, save into Documents, close
   and reopen the file. Verify `flatpak info --system` reports the app and runtime.
   Optional TeXLive/PDF functionality is outside the baseline.
4. Create a second desktop account. Verify shared Apostrophe launches, settings
   are per-user, and `flatpak remotes --user` contains enabled Flathub. Verify no
   Fedora remotes were created and no system units failed.
5. Restore networking. Delete/disable each Flathub remote and verify the matching
   system/user service repairs it. Repeat at a new account's first Bazaar launch.

## Bazaar source-selection and update gates

In disposable test installations:

- With system Apostrophe present, verify Bazaar recognizes the installed system
  app. An authorized system-app update must preserve system scope.
- Remove system Apostrophe through Bazaar with appropriate authorization. Wait
  for provisioning and reboot; it must stay removed. Keep the completion record.
- Search for Apostrophe through Bazaar and install it again. Verify it appears
  in `flatpak list --user`, not `flatpak list --system`, without an administrator
  prompt or a system-install source choice. Check search, detail, and app-link
  entry points supported by the selected release.
- Repeat in another account to verify independent user installations.
- For a real update test, use an older available signed Apostrophe revision in a
  disposable installation, then update through Bazaar to current stable. Verify
  document data survives and scope is unchanged. Also test a new runtime branch
  when available; non-enumerated remotes can affect dependency discovery.
- Confirm Bazaar has no OS-update interface; its native package changes only
  with the bootc image.

Do not bypass an observed scope-selection problem by adding a Bazaar patch or
exposing ordinary system installation. Report it as a blocker for this design.

## Future-default delivery and bootc persistence

Start with a test image whose default manifest omits Apostrophe. Upgrade to one
that includes it. Test offline, metered, and unknown metering first: no download
and no completion record. On an unmetered connection, run the service and verify
system app/runtime installation and a completion record. Interrupt a download;
retry must recover. Remove Apostrophe after success, then exercise reboot, a new
OS image, rollback, and unrelated manifest additions: it must remain removed.
Removing a default from the manifest must not uninstall an existing copy.
