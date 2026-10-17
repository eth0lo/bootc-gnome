# 4. GNOME Software asked for credentials to check updates

## Symptom and diagnosis

GNOME Software displayed an **Authentication Required** dialog saying
“Authentication is required to check available updates.” The screenshot
identified the action more precisely than the initial guess that this was a
PackageKit refresh.

The image included `gnome-software-rpm-ostree`. The rpm-ostree PolicyKit
action `org.projectatomic.rpmostree1.repo-refresh` carries the exact message
shown in the dialog and defaults to `auth_admin_keep`. Fedora's PackageKit
refresh policy therefore was not the source of this particular prompt.

## Resolution

Added a narrow PolicyKit rule in the [`Containerfile`](../Containerfile) for
`org.projectatomic.rpmostree1.repo-refresh`. It returns `YES` only when the
request comes from an **active local session** and the user belongs to
`wheel` or `sudo`.

The rule grants permission to refresh repository metadata (check for
available updates) only. It does not authorize rpm-ostree's `upgrade`,
package-install, rebase, rollback, or other actions; those retain their normal
authentication requirements.

## Verification and status

The rebuilt image was checked to contain the rule. A logic test confirmed that
it permits the refresh action for active local `wheel`/`sudo` users, while
rejecting other actions, non-admin users, and inactive sessions. The image,
QCOW2, and ISO were rebuilt, and the user later reported that the prompt was
gone in a fresh VM.
