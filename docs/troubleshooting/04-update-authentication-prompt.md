# 4. GNOME Software asked for credentials to check updates (superseded)

## Symptom and diagnosis

GNOME Software displayed an **Authentication Required** dialog saying
“Authentication is required to check available updates.” The screenshot
identified the action more precisely than the initial guess that this was a
PackageKit refresh.

The image included `gnome-software-rpm-ostree`. The rpm-ostree PolicyKit
action `org.projectatomic.rpmostree1.repo-refresh` carries the exact message
shown in the dialog and defaults to `auth_admin_keep`. Fedora's PackageKit
refresh policy therefore was not the source of this particular prompt.

## Historical resolution

The original workaround added a narrow PolicyKit rule for
`org.projectatomic.rpmostree1.repo-refresh`, copied into the image by the
Containerfile. That rule has since been removed along with GNOME Software and
its OS-update integrations; bootc is now the sole supported OS-update path.
The rationale and package-selection decisions are recorded in
[ADR 0001](../adr/0001-bootc-sole-os-update-path.md).

The historical rule only granted permission to refresh repository metadata. It
did not authorize rpm-ostree's `upgrade`, package-install, rebase, rollback, or
other actions.

## Verification and status

The original rebuilt image was checked to contain the rule, and a logic test
confirmed its scope. The image, QCOW2, and ISO were rebuilt, and the user later
reported that the prompt was gone in a fresh VM. This workaround is superseded:
GNOME Software and the authorization rule are no longer part of the image.
