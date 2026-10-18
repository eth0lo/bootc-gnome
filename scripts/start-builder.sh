#!/usr/bin/env bash
# Start the prepared builder VM and wait until its setup is finished.
# The VM runs in the background; SSH is forwarded only on host localhost.
# This script checks that guest sudo and Podman are ready to use.
#
# Run ./scripts/prepare-builder.sh once first, then run:
#   ./scripts/start-builder.sh
#
# Optional settings: BUILDER_SSH_PORT (default 2222), BUILDER_MEMORY_MB
# (default 8192), and BUILDER_CPUS (default 4).
# Requires QEMU/KVM, OVMF firmware, SSH tools, and timeout on the host.
# Runs as your normal user; it does not use host sudo.
set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder_dir="$repo_root/output/builder"
runtime="$builder_dir/runtime"
disk="$builder_dir/disk.qcow2"
seed="$builder_dir/cloud-init.iso"
port="${BUILDER_SSH_PORT:-2222}"
memory_mb="${BUILDER_MEMORY_MB:-8192}"
cpus="${BUILDER_CPUS:-4}"
known_hosts="$runtime/known_hosts"

if [[ ! -f "$disk" || ! -f "$seed" ]]; then
    printf 'Builder disk or cloud-init seed is missing; run ./scripts/prepare-builder.sh first.\n' >&2
    exit 1
fi
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    printf 'KVM is unavailable to this user. Check access to /dev/kvm.\n' >&2
    exit 1
fi
for tool in qemu-system-x86_64 ssh ssh-keygen timeout nohup; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required host tool not found: %s\n' "$tool" >&2
        exit 1
    fi
done

mkdir -p "$runtime"
vm_running=false
if [[ -f "$runtime/qemu.pid" ]]; then
    old_pid="$(<"$runtime/qemu.pid")"
    if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
        running_args="$(ps -p "$old_pid" -o args= 2>/dev/null || true)"
        if [[ "$running_args" == *"qemu-system-x86_64"*"-name bootc-builder"* ]]; then
            if [[ "$running_args" != *"hostfwd=tcp:127.0.0.1:${port}-:22"* ]]; then
                printf 'Builder VM is already running with a different SSH port. Stop it before changing BUILDER_SSH_PORT.\n' >&2
                exit 1
            fi
            vm_running=true
            printf 'Builder VM is already running (PID %s). Checking readiness.\n' "$old_pid"
        fi
    fi
    if [[ "$vm_running" != true ]]; then
        rm -f "$runtime/qemu.pid"
    fi
fi
if [[ ! -f "$runtime/id_ed25519" ]]; then
    printf 'Builder SSH key is missing; rerun ./scripts/prepare-builder.sh.\n' >&2
    exit 1
fi

if [[ "$vm_running" != true ]]; then
    if ( : > /dev/tcp/127.0.0.1/"$port" ) 2>/dev/null; then
        printf 'Host TCP port %s is already in use. Set BUILDER_SSH_PORT to another port.\n' "$port" >&2
        exit 1
    fi

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
        printf 'Could not locate an OVMF CODE/VARS pair; install OVMF firmware.\n' >&2
        exit 1
    fi
    if [[ ! -f "$runtime/OVMF_VARS.fd" ]]; then
        cp "$firmware_vars" "$runtime/OVMF_VARS.fd"
    fi

    nohup qemu-system-x86_64 \
        -name bootc-builder \
        -machine q35,accel=kvm \
        -cpu host \
        -smp "$cpus" \
        -m "$memory_mb" \
        -drive if=pflash,format=raw,readonly=on,file="$firmware_code" \
        -drive if=pflash,format=raw,file="$runtime/OVMF_VARS.fd" \
        -drive if=virtio,format=qcow2,file="$disk" \
        -drive media=cdrom,readonly=on,file="$seed" \
        -netdev user,id=net0,hostfwd="tcp:127.0.0.1:${port}-:22" \
        -device virtio-net-pci,netdev=net0 \
        -display none \
        -serial "file:$runtime/serial.log" \
        >"$runtime/qemu.log" 2>&1 </dev/null &
    qemu_pid=$!
    printf '%s\n' "$qemu_pid" > "$runtime/qemu.pid"
    sleep 1
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        rm -f "$runtime/qemu.pid"
        printf 'QEMU failed to start:\n' >&2
        cat "$runtime/qemu.log" >&2
        exit 1
    fi
fi

printf 'Ensuring Fedora builder VM is ready; checking SSH on port %s...\n' "$port"
ssh_args=(
    -i "$runtime/id_ed25519"
    -p "$port"
    -o BatchMode=yes
    -o ConnectTimeout=3
    -o StrictHostKeyChecking=accept-new
    -o "UserKnownHostsFile=$known_hosts"
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
)
connected=false
for attempt in {1..180}; do
    if ssh "${ssh_args[@]}" builder@127.0.0.1 true 2>/dev/null; then
        connected=true
        break
    fi
    sleep 5
done
if [[ "$connected" != true ]]; then
    printf 'Builder SSH did not become ready. Inspect %s/serial.log\n' "$runtime" >&2
    exit 1
fi

printf 'SSH is ready; waiting for cloud-init package provisioning to finish...\n'
if ! timeout 1800s ssh "${ssh_args[@]}" builder@127.0.0.1 'cloud-init status --wait' || \
   ! ssh "${ssh_args[@]}" builder@127.0.0.1 \
       'sudo -n true && sudo -n podman info --format "{{.Host.Security.Rootless}}" | grep -qx false && python3 -c "import shutil; assert shutil.disk_usage(\"/\").total >= 80 * 1024**3"'; then
    printf 'Builder provisioning failed or timed out. Inspect %s/serial.log and cloud-init logs in the guest.\n' "$runtime" >&2
    exit 1
fi
printf 'Builder VM is ready. Connect with ./scripts/builder-shell.sh\n'
