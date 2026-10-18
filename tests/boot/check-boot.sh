#!/usr/bin/bash
set -euo pipefail

expected_image="${1:?expected test image name required}"
actual_image="$(</usr/share/bootc-gnome/boot-test-image)"
if [[ "$actual_image" != "$expected_image" ]]; then
    printf 'Expected test image %s, but booted image marker is %s\n' \
        "$expected_image" "$actual_image" >&2
    exit 1
fi

[[ "$(systemctl get-default)" == graphical.target ]]
systemctl is-active --quiet graphical.target
systemctl is-active --quiet gdm.service
systemctl is-active --quiet sshd.service
systemctl is-enabled --quiet bootc-fetch-apply-updates.timer

failed_units="$(systemctl --failed --no-legend --plain)"
if [[ -n "$failed_units" ]]; then
    printf 'Systemd reports failed units:\n%s\n' "$failed_units" >&2
    exit 1
fi

service_exec="$(systemctl show bootc-fetch-apply-updates.service --property=ExecStart --value)"
if [[ "$service_exec" != *"/usr/libexec/bootc-gnome-upgrade"* ]]; then
    printf 'Unexpected update service command: %s\n' "$service_exec" >&2
    exit 1
fi
if [[ "$service_exec" == *"--apply"* ]]; then
    printf 'Update service would apply/reboot automatically: %s\n' "$service_exec" >&2
    exit 1
fi

printf 'PASS: booted test image %s\n' "$actual_image"
printf 'PASS: graphical.target and gdm.service are active\n'
printf 'PASS: SSH test access is active\n'
printf 'PASS: systemd reports no failed units\n'
printf 'PASS: bootc update timer is enabled and its command does not use --apply\n'
printf 'Boot ID: %s\n' "$(</proc/sys/kernel/random/boot_id)"
