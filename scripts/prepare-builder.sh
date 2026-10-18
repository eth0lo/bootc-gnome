#!/usr/bin/env bash
# Prepare the Fedora builder VM without using sudo on the host.
# Downloads and checks Fedora Cloud, creates a reusable virtual hard drive, and
# makes the small setup disk that gives the VM its login and build tools.
#
# Run from any folder:
#   ./scripts/prepare-builder.sh
#
# The first run downloads about 560 MB. Files are kept under output/builder/.
# Later runs reuse the downloaded base, virtual hard drive, and SSH key.
# The VM must be stopped before preparing it again.
#
# Requires curl, qemu-img, xorriso, ssh-keygen, Python 3, and KVM access.
# No sudo password is needed.
set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder_dir="$repo_root/output/builder"
base_dir="$builder_dir/base"
runtime_dir="$builder_dir/runtime"
seed_dir="$builder_dir/seed"
base_name=Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
base_url="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/$base_name"
base_sha256=28680fe5b371a5a82ebf43a31926e086a168e59949d03969c5093e7071f90b7f
disk="$builder_dir/disk.qcow2"
disk_size=120G

for tool in curl qemu-img xorriso ssh-keygen python3 sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required host tool not found: %s\n' "$tool" >&2
        exit 1
    fi
done
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    printf 'KVM is unavailable to this user. Check /dev/kvm access; preparation itself does not use sudo.\n' >&2
    exit 1
fi

mkdir -p "$base_dir" "$runtime_dir" "$seed_dir"
pidfile="$runtime_dir/qemu.pid"
if [[ -f "$pidfile" ]]; then
    pid="$(<"$pidfile")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null && \
       [[ "$(ps -p "$pid" -o args= 2>/dev/null || true)" == *"qemu-system-x86_64"*"-name bootc-builder"* ]]; then
        printf 'Builder VM is running. Stop it before preparing or inspecting its disk.\n' >&2
        exit 1
    fi
fi

base="$base_dir/$base_name"
if [[ ! -f "$base" ]]; then
    partial="$base.part"
    rm -f "$partial"
    curl --fail --location --retry 3 --output "$partial" "$base_url"
    printf '%s  %s\n' "$base_sha256" "$partial" | sha256sum --check --status || {
        rm -f "$partial"
        printf 'Fedora Cloud image checksum did not match the pinned Fedora 44.1.7 checksum.\n' >&2
        exit 1
    }
    mv "$partial" "$base"
fi
printf '%s  %s\n' "$base_sha256" "$base" | sha256sum --check --status || {
    printf 'Cached Fedora Cloud image checksum mismatch: %s\n' "$base" >&2
    exit 1
}

if [[ -e "$disk" ]]; then
    python3 - "$disk" "$base" "$disk_size" <<'PY'
import json
import pathlib
import subprocess
import sys

disk = pathlib.Path(sys.argv[1])
base = pathlib.Path(sys.argv[2])
expected_size = int(sys.argv[3][:-1]) * 1024**3
info = json.loads(subprocess.check_output(["qemu-img", "info", "--output=json", str(disk)]))
actual_backing = pathlib.Path(info.get("backing-filename", ""))
if not actual_backing.is_absolute():
    actual_backing = (disk.parent / actual_backing).resolve()
if info.get("virtual-size", 0) < expected_size:
    raise SystemExit(f"Existing builder disk is smaller than 120 GiB: {info.get('virtual-size')}")
if actual_backing.resolve() != base.resolve():
    raise SystemExit(f"Existing builder disk uses unexpected backing image: {actual_backing}")
print(f"Reusing existing builder disk: {disk}")
PY
else
    qemu-img create -f qcow2 -F qcow2 -b "$base" "$disk" "$disk_size"
fi

if [[ ! -f "$runtime_dir/id_ed25519" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C bootc-gnome-builder -f "$runtime_dir/id_ed25519"
fi

python3 - "$repo_root/builder/cloud-init.yaml" "$seed_dir/user-data" "$runtime_dir/id_ed25519.pub" <<'PY'
import json
import pathlib
import sys

template_path, output_path, public_key_path = map(pathlib.Path, sys.argv[1:])
template = template_path.read_text()
public_key = public_key_path.read_text().strip()
token = "@@BUILDER_SSH_PUBLIC_KEY@@"
if not public_key.startswith(("ssh-ed25519 ", "ssh-rsa ", "ecdsa-sha2-")):
    raise SystemExit("Generated SSH public key has an unsupported format")
if template.count(token) != 1:
    raise SystemExit(f"Cloud-init template must contain exactly one {token} placeholder")
output_path.write_text(template.replace(token, json.dumps(public_key)))
PY

metadata="$seed_dir/meta-data"
if [[ ! -f "$metadata" ]]; then
    printf 'instance-id: bootc-gnome-builder\nlocal-hostname: bootc-builder\n' > "$metadata"
fi

seed_tmp="$builder_dir/cloud-init.iso.tmp"
xorriso -as mkisofs -quiet -output "$seed_tmp" -volid cidata -joliet -rock "$seed_dir"
mv "$seed_tmp" "$builder_dir/cloud-init.iso"

printf 'Builder disk: %s\nCloud-init seed: %s/cloud-init.iso\n' "$disk" "$builder_dir"
