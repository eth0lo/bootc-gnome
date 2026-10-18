#!/usr/bin/env python3
"""Install the actual ISO without a NIC, then inspect it over restricted SSH.

The separate OEMDRV disc supplies only unattended answers and a disposable SSH
key. The production ISO and embedded OS image are not modified.
"""

import argparse
from pathlib import Path
import shutil
import subprocess
import time


def run_checked(*command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iso", type=Path)
    parser.add_argument("--port", type=int, default=2244)
    parser.add_argument("--resume", type=Path, help="recheck an already installed test output directory")
    parser.add_argument("--online", action="store_true", help="test Bazaar user installation on a disposable disk overlay with networking")
    args = parser.parse_args()
    iso = args.iso.resolve(strict=True)
    root = Path(__file__).resolve().parents[2]
    output = args.resume.resolve(strict=True) if args.resume else root / "output/flatpak-iso-tests" / time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    output.mkdir(parents=True, mode=0o700, exist_ok=bool(args.resume))
    firmware = next((Path(path) for path in (
        "/usr/share/edk2/ovmf/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_CODE.fd",
        "/usr/share/edk2/ovmf/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_CODE_4M.fd",
    ) if Path(path).exists()), None)
    if firmware is None:
        raise SystemExit("OVMF firmware not found")
    variables = firmware.with_name(firmware.name.replace("CODE", "VARS"))
    if not args.resume:
        shutil.copyfile(variables, output / "OVMF_VARS.fd")
    for source, destination in (("/images/pxeboot/vmlinuz", "vmlinuz"),
                                ("/images/pxeboot/initrd.img", "initrd.img"),
                                ("/osbuild.ks", "osbuild.ks")):
        if not args.resume:
            run_checked("xorriso", "-osirrox", "on", "-indev", str(iso), "-extract", source, str(output / destination))
    if not args.resume:
        run_checked("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(output / "id_ed25519"))
    key = (output / "id_ed25519.pub").read_text().strip()
    seed = output / "seed"
    seed.mkdir(exist_ok=bool(args.resume))
    (seed / "ks.cfg").write_text(f'''text
lang en_US.UTF-8
keyboard us
timezone Etc/UTC --utc
rootpw --lock
user --name=flatpak-test --groups=wheel --lock
sshkey --username=flatpak-test "{key}"
zerombr
ignoredisk --only-use=vda
clearpart --all --initlabel --drives=vda
autopart --type=btrfs --nohome
services --enabled=sshd
poweroff
%include /run/install/repo/osbuild.ks
%post --erroronfail
printf 'flatpak-test ALL=(ALL) NOPASSWD: ALL\\n' > /etc/sudoers.d/90-flatpak-test
chmod 0440 /etc/sudoers.d/90-flatpak-test
systemctl set-default graphical.target
%end
''')
    if not args.resume:
        run_checked("xorriso", "-as", "mkisofs", "-quiet", "-V", "OEMDRV", "-o", str(output / "seed.iso"), str(seed))
        run_checked("qemu-img", "create", "-f", "qcow2", str(output / "disk.qcow2"), "32G")
    common = ["qemu-system-x86_64", "-machine", "q35,accel=kvm", "-cpu", "host",
              "-smp", "4", "-m", "6144", "-display", "none",
              "-drive", f"if=pflash,format=raw,readonly=on,file={firmware}",
              "-drive", f"if=pflash,format=raw,file={output / 'OVMF_VARS.fd'}",
              "-drive", f"if=virtio,format=qcow2,file={output / 'disk.qcow2'}"]
    print(f"{'Rechecking installed disk' if args.resume else 'Installing offline'}; evidence: {output}", flush=True)
    if not args.resume:
        with (output / "installer-qemu.log").open("w") as log:
            run_checked(*common, "-nic", "none", "-no-reboot",
                        "-serial", f"file:{output / 'installer-serial.log'}",
                        "-drive", f"file={iso},media=cdrom,readonly=on",
                        "-drive", f"file={output / 'seed.iso'},media=cdrom,readonly=on",
                        "-kernel", str(output / "vmlinuz"), "-initrd", str(output / "initrd.img"),
                        "-append", "inst.stage2=hd:LABEL=Fedora-S-dvd-x86_64-44 inst.ks=hd:LABEL=OEMDRV:/ks.cfg inst.cmdline console=ttyS0",
                        stdout=log, stderr=subprocess.STDOUT, timeout=1800)
    if "Install finished" not in (output / "installer-serial.log").read_text(errors="replace"):
        raise SystemExit(f"Installation did not reach completion; inspect {output}")
    if args.online:
        overlay = output / f"online-{time.time_ns()}.qcow2"
        run_checked("qemu-img", "create", "-f", "qcow2", "-F", "qcow2", "-b", str(output / "disk.qcow2"), str(overlay))
        common[-1] = f"if=virtio,format=qcow2,file={overlay}"
    ssh = ["ssh", "-i", str(output / "id_ed25519"), "-p", str(args.port),
           "-o", "BatchMode=yes", "-o", "ConnectTimeout=3", "-o", "StrictHostKeyChecking=accept-new",
           "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
           "-o", f"UserKnownHostsFile={output / 'known_hosts'}", "flatpak-test@127.0.0.1"]
    # restrict=on permits inbound host-forwarded SSH, but blocks guest access to
    # the Internet and host services. Installation itself had no NIC at all.
    with (output / "boot-qemu.log").open("w") as log:
        guest = subprocess.Popen([*common, "-serial", f"file:{output / 'boot-serial.log'}",
                                  "-netdev", f"user,id=net0,restrict={'off' if args.online else 'on'},hostfwd=tcp:127.0.0.1:{args.port}-:22",
                                  "-device", "virtio-net-pci,netdev=net0"], stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(120):
                try:
                    ready = subprocess.run([*ssh, "true"], stdout=subprocess.DEVNULL,
                                           stderr=subprocess.DEVNULL, timeout=15).returncode == 0
                except subprocess.TimeoutExpired:
                    ready = False
                if ready:
                    break
                if guest.poll() is not None:
                    raise SystemExit("Installed guest exited before SSH became available")
                time.sleep(5)
            else:
                raise SystemExit("Installed guest SSH timed out")
            check = '''set -eu
rpm -q bazaar
flatpak info --system org.gnome.gitlab.somas.Apostrophe//stable
test -f /var/lib/bootc-gnome-flatpaks/org.gnome.gitlab.somas.Apostrophe
/usr/libexec/bootc-gnome-flathub user
flatpak remotes --user --show-details
flatpak remotes --system --show-details
# The unattended text installer selects multi-user.target even though the
# production graphical installer and QCOW2 use graphical.target. Start the
# desktop explicitly in this harness (the kickstart also sets future boots).
sudo -n systemctl start graphical.target
systemctl is-active gdm.service
test -z "$(sudo -n systemctl --failed --no-legend)"
'''
            with (output / "installed-health.txt").open("w") as result:
                run_checked(*ssh, "bash -s", input=check, text=True, stdout=result, stderr=subprocess.STDOUT, timeout=120)
            # Enable automatic login only in this disposable installation so
            # actual GNOME/Wayland windows can be checked without a human.
            run_checked(*ssh, "if ! sudo -n grep -q '^AutomaticLogin=flatpak-test$' /etc/gdm/custom.conf; then sudo -n sh -c 'printf \"[daemon]\\nAutomaticLoginEnable=True\\nAutomaticLogin=flatpak-test\\n\" > /etc/gdm/custom.conf'; sudo -n systemctl restart gdm.service; fi", timeout=120)
            with (output / ("online-session.txt" if args.online else "offline-session.txt")).open("w") as result:
                command = "python3 - --install" if args.online else "python3 -"
                run_checked(*ssh, command,
                    input=(root / "tests/flatpak/check-session.py").read_text(),
                    text=True, stdout=result, stderr=subprocess.STDOUT, timeout=600 if args.online else 300)
            print(f"PASS: {'Bazaar per-user installation' if args.online else 'actual offline ISO installation and desktop workflow'}; evidence: {output}")
        finally:
            try:
                with (output / "session-journal.txt").open("w") as journal:
                    subprocess.run([*ssh, "journalctl --user --boot --no-pager"],
                                   stdout=journal, stderr=subprocess.STDOUT, timeout=20)
            except (OSError, subprocess.TimeoutExpired):
                pass
            finally:
                try:
                    subprocess.run([*ssh, "sudo -n systemctl poweroff"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
                except (OSError, subprocess.TimeoutExpired):
                    pass
                try:
                    guest.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    guest.terminate()
                    try:
                        guest.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        guest.kill()
                        guest.wait()


if __name__ == "__main__":
    main()
