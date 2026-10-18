"""Exercise the delivery CLI against a simulated Flatpak/NetworkManager boundary.

These tests cover durable delivery decisions, not GUI or dependency correctness;
the real-image and Apostrophe checks cover those separately.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "files/usr/libexec/bootc-gnome-flatpak-defaults"
APP = "org.gnome.gitlab.somas.Apostrophe"

BACKEND = '''#!/usr/bin/python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ["TEST_BACKEND"])
s = json.loads(p.read_text())
a = sys.argv[1:]
command = pathlib.Path(sys.argv[0]).name
s["calls"].append([command, *a])
code = 0
if command == "busctl":
    print(s["metering"])
    code = s.get("network_error", 0)
elif a[0] == "info":
    code = 0 if a[-1] in s["installed"] else 1
elif a[0] == "remote-info":
    print("org.gnome.Platform/x86_64/51")
elif a[0] == "install":
    if (s.get("fail_install") and not a[-1].startswith("runtime/")) or a[-1] in s.get("fail_refs", []):
        code = 1
        print("interrupted download", file=sys.stderr)
    elif a[-1] not in s["installed"]:
        s["installed"].append(a[-1])
p.write_text(json.dumps(s))
sys.exit(code)
'''


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.manifest = self.root / "defaults"
        self.manifest.write_text(APP + "\n")
        self.state = self.root / "state"
        self.backend = self.root / "backend.json"
        self.save(installed=[], calls=[], metering="u 2")
        for command in ("flatpak", "busctl"):
            executable = self.root / command
            executable.write_text(BACKEND)
            executable.chmod(0o755)

    def save(self, **state):
        self.backend.write_text(json.dumps(state))

    def load(self):
        return json.loads(self.backend.read_text())

    def deliver(self, *args):
        return subprocess.run(
            [sys.executable, str(HELPER), "--manifest", str(self.manifest),
             "--state-dir", str(self.state), *args],
            env={**os.environ, "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
                 "TEST_BACKEND": str(self.backend)},
            text=True, capture_output=True,
        )

    def test_delivery_does_not_undo_removal(self):
        result = self.deliver()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(APP + "//stable", self.load()["installed"])
        self.assertTrue((self.state / APP).exists())
        self.save(installed=[], calls=[], metering="u 2")
        self.assertEqual(self.deliver().returncode, 0)
        self.assertEqual(self.load()["installed"], [])
        self.assertEqual(self.load()["calls"], [])

    def test_metered_unknown_and_offline_defer_without_recording_delivery(self):
        for value, error in (("u 0", 0), ("u 1", 0), ("u 3", 0), ("u 4", 0), ("", 1)):
            with self.subTest(metering=value):
                self.save(installed=[], calls=[], metering=value, network_error=error)
                self.assertEqual(self.deliver().returncode, 0)
                self.assertFalse((self.state / APP).exists())
                self.assertEqual(self.load()["installed"], [])
        self.save(installed=[], calls=[], metering="u 2")
        self.assertEqual(self.deliver().returncode, 0)
        self.assertTrue((self.state / APP).exists())

    def test_partial_failure_is_retried_and_only_success_records_delivery(self):
        self.save(installed=[], calls=[], metering="u 2", fail_install=True)
        self.assertNotEqual(self.deliver().returncode, 0)
        self.assertFalse((self.state / APP).exists())
        state = self.load()
        state["fail_install"] = False
        self.save(**state)
        self.assertEqual(self.deliver().returncode, 0)
        self.assertTrue((self.state / APP).exists())

    def test_preexisting_system_app_is_recorded_even_offline(self):
        self.save(installed=[APP + "//stable"], calls=[], metering="u 0")
        self.assertEqual(self.deliver().returncode, 0)
        self.assertTrue((self.state / APP).exists())
        self.assertFalse(any(call[0] == "busctl" for call in self.load()["calls"]))

    def test_later_manifest_addition_does_not_reintroduce_removed_default(self):
        self.assertEqual(self.deliver("--seed").returncode, 0)
        later = "org.example.Later"
        self.manifest.write_text(APP + "\n" + later + "\n")
        self.save(installed=[], calls=[], metering="u 2")
        self.assertEqual(self.deliver().returncode, 0)
        self.assertNotIn(APP + "//stable", self.load()["installed"])
        self.assertIn(later + "//stable", self.load()["installed"])

    def test_invalid_manifest_is_rejected_before_running_flatpak(self):
        self.manifest.write_text("../../not-an-app\n")
        self.assertNotEqual(self.deliver().returncode, 0)
        self.assertEqual(self.load()["calls"], [])

    def test_one_unavailable_app_does_not_starve_later_defaults(self):
        later = "org.example.Later"
        self.manifest.write_text(APP + "\n" + later + "\n")
        self.save(installed=[], calls=[], metering="u 2", fail_refs=[APP + "//stable"])
        self.assertNotEqual(self.deliver().returncode, 0)
        self.assertFalse((self.state / APP).exists())
        self.assertTrue((self.state / later).exists())


if __name__ == "__main__":
    unittest.main()
