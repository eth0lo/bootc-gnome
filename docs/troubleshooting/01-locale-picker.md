# 1. Locale picker had no available locales

## Symptom

During first boot, GNOME Initial Setup's language/locale picker did not offer
any locales to select.

## Cause

The Fedora bootc base and selected GNOME package groups did not include the
English glibc locale data required to populate the picker.

## Resolution

Added `glibc-langpack-en` to the explicit package installation in the
[`Containerfile`](../../Containerfile). At the time, the image was pinned to
Fedora 43 so the installed package groups and documented group selection used
the same release. The current local image uses Fedora 44; see
[`FEDORA-44-GROUPS.md`](../../FEDORA-44-GROUPS.md).

## Verification and status

The rebuilt image and installer ISO were generated with `glibc-langpack-en`
installed. The local image package check confirmed the locale package was
present. No later report indicated that the empty locale picker persisted.
