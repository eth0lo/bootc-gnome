#!/usr/bin/env bash
# Build a test-only desktop image, boot it in a disposable VM, and check that
# the graphical desktop and stage-only update configuration come up correctly.
#
# Run from any folder:
#   ./scripts/test-boot.sh
#
# The test starts the builder VM if needed, but leaves an already-running
# builder VM running. It creates a temporary test SSH key and a disposable
# QEMU disk under output/boot-tests/. Logs are kept there for diagnosis.
#
# Requires the local Fedora builder VM and host QEMU/KVM with OVMF firmware.
# No host sudo access is used. Set BOOT_TEST_SSH_PORT, BOOT_TEST_MEMORY_MB, or
# BOOT_TEST_CPUS to change the test VM defaults (2233, 6144 MiB, and 4 CPUs).
set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder_dir="$repo_root/output/builder"
builder_runtime="$builder_dir/runtime"
output_root="$repo_root/output/boot-tests"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
run_dir="$output_root/$run_id"
remote_workdir="bootc-gnome-boot-tests/$run_id"
base_image="localhost/bootc-gnome:boot-base-$run_id"
test_image="localhost/bootc-gnome:boot-test-$run_id"
builder_started=false
remote_cleanup_needed=false
test_qemu_pid=
test_ssh_port="${BOOT_TEST_SSH_PORT:-2233}"
test_memory_mb="${BOOT_TEST_MEMORY_MB:-6144}"
test_cpus="${BOOT_TEST_CPUS:-4}"

mkdir -p "$run_dir"
ssh_key="$run_dir/id_ed25519"
ssh_known_hosts="$run_dir/known_hosts"
serial_log="$run_dir/serial.log"
qemu_log="$run_dir/qemu.log"
disk="$run_dir/disk.qcow2"

for tool in qemu-system-x86_64 qemu-img ssh ssh-keygen timeout python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required host tool not found: %s\n' "$tool" >&2
        exit 1
    fi
done
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    printf 'KVM is unavailable to this user. Check access to /dev/kvm.\n' >&2
    exit 1
fi

python3 - "$test_ssh_port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
with socket.socket() as sock:
    try:
        sock.bind(("127.0.0.1", port))
    except OSError as exc:
        raise SystemExit(f"Test SSH port {port} is unavailable: {exc}")
PY

firmware_pairs=(
    "/usr/share/edk2/ovmf/OVMF_CODE.fd|/usr/share/edk2/ovmf/OVMF_VARS.fd"
    "/usr/share/edk2/ovmf/OVMF_CODE_4M.fd|/usr/share/edk2/ovmf/OVMF_VARS_4M.fd"
    "/usr/share/OVMF/OVMF_CODE.fd|/usr/share/OVMF/OVMF_VARS.fd"
    "/usr/share/OVMF/OVMF_CODE_4M.fd|/usr/share/OVMF/OVMF_VARS_4M.fd"
)
firmware_code=
firmware_vars=
for pair in "${firmware_pairs[@]}"; do
    code="${pair%%|*}"
    vars="${pair#*|}"
    if [[ -r "$code" && -r "$vars" ]]; then
        firmware_code="$code"
        firmware_vars="$vars"
        break
    fi
done
if [[ -z "$firmware_code" ]]; then
    printf 'Could not find OVMF firmware; install OVMF on the host.\n' >&2
    exit 1
fi

ssh-keygen -q -t ed25519 -N '' -C "bootc-gnome-boot-test-$run_id" -f "$ssh_key"

builder_is_running() {
    local pidfile="$builder_runtime/qemu.pid"
    local pid args
    [[ -f "$pidfile" ]] || return 1
    pid="$(<"$pidfile")"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    [[ "$args" == *"qemu-system-x86_64"*"-name bootc-builder"* ]]
}

builder_exec() {
    "$repo_root/scripts/builder-exec.sh" bash -lc "$1"
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM

    if [[ -n "$test_qemu_pid" ]] && kill -0 "$test_qemu_pid" 2>/dev/null; then
        ssh -i "$ssh_key" -p "$test_ssh_port" \
            -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
            -o "UserKnownHostsFile=$ssh_known_hosts" \
            boot-test@127.0.0.1 'sudo -n systemctl poweroff' >/dev/null 2>&1 || true
        for attempt in {1..15}; do
            kill -0 "$test_qemu_pid" 2>/dev/null || break
            sleep 1
        done
        if kill -0 "$test_qemu_pid" 2>/dev/null; then
            kill "$test_qemu_pid" 2>/dev/null || true
        fi
        wait "$test_qemu_pid" 2>/dev/null || true
    fi

    if [[ "$remote_cleanup_needed" == true ]] && builder_exec \
        "sudo podman rmi --force '$test_image' '$base_image' >/dev/null 2>&1 || true; rm -rf \"\$HOME/$remote_workdir\"" \
        >/dev/null 2>&1; then
        :
    fi

    if [[ "$builder_started" == true ]]; then
        "$repo_root/scripts/stop-builder.sh" >/dev/null 2>&1 || true
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ! -f "$builder_dir/disk.qcow2" || ! -f "$builder_runtime/id_ed25519" ]]; then
    if builder_is_running; then
        printf 'Builder is running but its disk or SSH key is missing; refusing to prepare it.\n' >&2
        exit 1
    fi
    "$repo_root/scripts/prepare-builder.sh"
fi

if ! builder_is_running; then
    builder_started=true
fi
"$repo_root/scripts/start-builder.sh"
"$repo_root/scripts/builder-sync.sh"

test_public_key="$(<"$ssh_key.pub")"
printf -v build_command \
    'cd ~/bootc-gnome && ./scripts/build-image.sh %q && sudo podman build --pull=never --build-arg BASE_IMAGE=%q --build-arg TEST_SSH_PUBKEY=%q --build-arg TEST_IMAGE=%q --tag %q --file tests/boot/Containerfile .' \
    "$base_image" "$base_image" "$test_public_key" "$test_image" "$test_image"
remote_cleanup_needed=true
builder_exec "$build_command"

printf -v qcow_command \
    'mkdir -p "$HOME/%s" && cd "$HOME/%s" && "$HOME/bootc-gnome/scripts/build-qcow2.sh" %q' \
    "$remote_workdir" "$remote_workdir" "$test_image"
builder_exec "$qcow_command"

"$repo_root/scripts/builder-fetch.sh" "$remote_workdir/output/qcow2/disk.qcow2" "$run_dir"
qemu-img check "$disk" > "$run_dir/qemu-img-check.txt"

if builder_exec "sudo podman rmi --force '$test_image' '$base_image' >/dev/null 2>&1 || true; rm -rf \"\$HOME/$remote_workdir\"" \
    >/dev/null 2>&1; then
    remote_cleanup_needed=false
fi
if [[ "$builder_started" == true ]]; then
    "$repo_root/scripts/stop-builder.sh"
    builder_started=false
fi

cp "$firmware_vars" "$run_dir/OVMF_VARS.fd"
qemu-system-x86_64 \
    -name bootc-boot-test \
    -machine q35,accel=kvm \
    -cpu host \
    -smp "$test_cpus" \
    -m "$test_memory_mb" \
    -drive if=pflash,format=raw,readonly=on,file="$firmware_code" \
    -drive if=pflash,format=raw,file="$run_dir/OVMF_VARS.fd" \
    -drive if=virtio,format=qcow2,file="$disk" \
    -netdev user,id=net0,hostfwd="tcp:127.0.0.1:${test_ssh_port}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -serial "file:$serial_log" \
    >"$qemu_log" 2>&1 </dev/null &
test_qemu_pid=$!
printf '%s\n' "$test_image" > "$run_dir/expected-image.txt"

ssh_args=(
    -i "$ssh_key"
    -p "$test_ssh_port"
    -o BatchMode=yes
    -o ConnectTimeout=3
    -o StrictHostKeyChecking=accept-new
    -o "UserKnownHostsFile=$ssh_known_hosts"
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
)
printf 'Booting test image %s; waiting for guest SSH...\n' "$test_image"
connected=false
for attempt in {1..120}; do
    if ssh "${ssh_args[@]}" boot-test@127.0.0.1 true 2>/dev/null; then
        connected=true
        break
    fi
    if ! kill -0 "$test_qemu_pid" 2>/dev/null; then
        printf 'Test VM stopped before SSH became available. See %s/serial.log\n' "$run_dir" >&2
        exit 1
    fi
    sleep 5
done
if [[ "$connected" != true ]]; then
    printf 'Test VM SSH did not become ready. See %s/serial.log\n' "$run_dir" >&2
    exit 1
fi

ssh "${ssh_args[@]}" boot-test@127.0.0.1 'sudo -n bootc status' \
    > "$run_dir/bootc-status.txt"
ssh "${ssh_args[@]}" boot-test@127.0.0.1 \
    'sudo -n systemctl show bootc-fetch-apply-updates.service --property=FragmentPath --property=DropInPaths --property=ExecStart --property=CPUWeight --property=IOWeight --property=Nice --property=IOSchedulingClass && sudo -n systemctl show bootc-fetch-apply-updates.timer --property=FragmentPath --property=DropInPaths --property=Triggers --property=TimersCalendar --property=TimersMonotonic --property=NextElapseUSecMonotonic --property=UnitFileState' \
    > "$run_dir/update-units.txt"
ssh "${ssh_args[@]}" boot-test@127.0.0.1 \
    'sudo -n systemctl cat bootc-fetch-apply-updates.service bootc-fetch-apply-updates.timer' \
    > "$run_dir/unit-files.txt"
ssh "${ssh_args[@]}" boot-test@127.0.0.1 \
    'sudo -n systemctl --failed --no-legend --plain' \
    > "$run_dir/failed-units.txt"
ssh "${ssh_args[@]}" boot-test@127.0.0.1 \
    'sudo -n journalctl --boot --no-pager' \
    > "$run_dir/journal.txt"

printf 'Waiting for desktop and update-service checks...\n'
health_ok=false
for attempt in {1..60}; do
    if timeout 30s ssh "${ssh_args[@]}" boot-test@127.0.0.1 \
        sudo -n /usr/local/sbin/bootc-gnome-check-boot "$test_image" \
        > "$run_dir/health-check.txt" 2>&1; then
        health_ok=true
        break
    fi
    sleep 5
done
if [[ "$health_ok" != true ]]; then
    printf 'Boot health checks failed. Evidence is in %s\n' "$run_dir" >&2
    exit 1
fi

printf 'PASS: builder booted %s and passed desktop/update checks.\n' "$test_image"
printf 'Evidence: %s\n' "$run_dir"
