# 3. The first user's home directory was missing

## Symptom and diagnosis

GNOME Terminal failed to launch with an error that it could not change to
`/home/jean`. A text-console login confirmed that the `jean` account existed
and had `/home/jean` in its passwd entry, but that directory did not exist.
`/home` resolved to `/var/home`; `/var/home` itself existed, while
`/var/home/jean` did not. The login therefore fell back to `/`.

## Immediate repair for the affected VM

The missing directory was created with the account's ownership:

```sh
sudo install -d -o jean -g jean -m 0750 /var/home/jean
```

After this command, Terminal worked. This repaired that VM only; it did not
change the image.

## Permanent image resolution

The first image change created `/var/home`, but that only created the parent,
not each user's home. The final image configuration now:

- Keeps `/var/home` present at boot using an image directory and the
  [`bootc-gnome-home.conf`](../../files/usr/lib/tmpfiles.d/bootc-gnome-home.conf)
  tmpfiles entry.
- Installs Fedora's `domain-client` group (Fedora 43 at the time of the
  original fix), which includes
  `oddjob-mkhomedir` and its `oddjob` service dependency, as well as the
  domain/Samba tools intentionally requested for the image.
- Enables authselect's `with-mkhomedir` feature. This adds
  `pam_oddjob_mkhomedir.so` to the PAM session stack so a missing home is
  created during the user's first login.
- Enables `oddjobd.service` so PAM's home-creation module can perform the
  operation.

GNOME Initial Setup remains included in the selected GNOME desktop packages;
its redundant explicit package entry was removed. The `domain-client` group was
not the cause of the original missing directory—the issue was that the image
had no reliable per-user home-creation mechanism.

## Verification and status

The rebuilt image was checked for `oddjob-mkhomedir`, the active authselect
feature, the generated PAM hook, and the enabled oddjob service. The user later
reported that a fresh VM boots without the home error.
