#!/usr/bin/python3
"""Check real GTK windows in the disposable ISO test user's GNOME session."""

import os
import getpass
from pathlib import Path
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, Gio, GLib


def wait_for_window(application, title=None):
    for _ in range(120):
        desktop = Atspi.get_desktop(0)
        for index in range(desktop.get_child_count()):
            app = desktop.get_child_at_index(index)
            if application.lower() not in (app.get_name() or "").lower():
                continue
            app.set_cache_mask(Atspi.Cache.NONE)
            for child_index in range(app.get_child_count()):
                window = app.get_child_at_index(child_index)
                name = window.get_name() or ""
                if window.get_role_name() in ("frame", "window", "dialog") and (title is None or title in name):
                    print(f"PASS: {application} window in installed GNOME session: {name}", flush=True)
                    return window
        time.sleep(1)
    raise SystemExit(f"No accessible {application} window appeared")


def descendants(window):
    context = GLib.MainContext.default()
    while context.pending():
        context.iteration(False)
    pending = [window]
    while pending:
        node = pending.pop(0)
        if node is None:
            continue
        node.clear_cache()
        yield node
        pending.extend(node.get_child_at_index(index) for index in range(node.get_child_count()))


def button(window, name):
    for attempt in range(30):
        nodes = list(descendants(window))
        for node in nodes:
            if node.get_name() == name and node.get_role_name() in ("button", "toggle button"):
                return node
        if attempt == 0:
            for node in nodes:
                if node.get_name() == "Show Toolbar" and node.get_role_name() == "toggle button":
                    node.get_action_iface().do_action(0)
                    break
        time.sleep(1)
    raise SystemExit(f"Apostrophe button did not appear: {name}; controls: "
                     + repr([(node.get_role_name(), node.get_name()) for node in descendants(window)
                             if node.get_role_name() in ("button", "toggle button")]))


def editor(window):
    return next(node for node in descendants(window) if "EditableText" in node.get_interfaces())


def window_action(action):
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    name = "org.gnome.gitlab.somas.Apostrophe"
    path = "/org/gnome/gitlab/somas/Apostrophe/window"
    xml = bus.call_sync(name, path, "org.freedesktop.DBus.Introspectable", "Introspect",
                        None, None, Gio.DBusCallFlags.NONE, 10000, None).unpack()[0]
    available = []
    for node in ET.fromstring(xml).findall("node"):
        window_path = path + "/" + node.attrib["name"]
        actions = bus.call_sync(name, window_path, "org.gtk.Actions", "List", None,
                               None, Gio.DBusCallFlags.NONE, 10000, None).unpack()[0]
        available.extend(actions)
        if action in actions:
            bus.call_sync(name, window_path, "org.gtk.Actions", "Activate",
                          GLib.Variant("(sava{sv})", (action, [], {})), None,
                          Gio.DBusCallFlags.NONE, 10000, None)
            return
    raise SystemExit(f"Missing Apostrophe action {action}; available: {available}")


def install_through_bazaar():
    subprocess.run(["sudo", "-n", "flatpak", "uninstall", "--system", "--assumeyes",
                    "--noninteractive", "org.gnome.gitlab.somas.Apostrophe"], check=True)
    subprocess.run(["systemd-run", "--user", "--collect", "--unit=flatpak-test-bazaar",
                    "--setenv=WAYLAND_DISPLAY=wayland-0", "--setenv=GDK_BACKEND=wayland",
                    "bazaar-daemon"], check=True)
    Atspi.init()
    window = wait_for_window("Bazaar")
    subprocess.run(["bazaar", "--search-for", "Apostrophe"], check=True)
    for _ in range(180):
        controls = list(descendants(window))
        results = [node for node in controls
                   if node.get_name() == "Get" and node.get_role_name() == "button"]
        if results:
            click(results[0])
            break
        time.sleep(1)
    else:
        controls = [(node.get_role_name(), node.get_name()) for node in descendants(window)
                    if node.get_name()]
        raise SystemExit(f"Apostrophe search result did not appear: {controls}")
    for _ in range(60):
        if subprocess.run(["flatpak", "info", "--user", "org.gnome.gitlab.somas.Apostrophe//stable"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        controls = list(descendants(window))
        install = next((node for node in controls if node.get_role_name() == "button"
                        and (node.get_name() or "").startswith("Install")), None)
        if install:
            click(install)
            break
        time.sleep(1)
    else:
        raise SystemExit("Bazaar's ordinary Install action did not appear: "
                         + repr([(node.get_role_name(), node.get_name()) for node in descendants(window)
                                 if node.get_name()]))
    for _ in range(180):
        result = subprocess.run(["flatpak", "info", "--user", "org.gnome.gitlab.somas.Apostrophe//stable"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode == 0:
            break
        time.sleep(1)
    else:
        raise SystemExit("Bazaar did not complete a user-scope installation")
    result = subprocess.run(["flatpak", "info", "--system", "org.gnome.gitlab.somas.Apostrophe//stable"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode == 0:
        raise SystemExit("Bazaar installed Apostrophe system-wide instead of per-user")
    remotes = subprocess.run(["flatpak", "remotes", "--system", "--columns=name,options"],
                             check=True, capture_output=True, text=True).stdout
    if not any(line.startswith("flathub\t") and "no-enumerate" in line for line in remotes.splitlines()):
        raise SystemExit("Bazaar changed system Flathub into an enumerable application source")
    print(remotes, end="", flush=True)
    print("PASS: ordinary Bazaar Install delivered Apostrophe per-user, without a system installation", flush=True)


def click(node):
    action = node.get_action_iface()
    if action is None or action.get_n_actions() == 0:
        raise SystemExit(f"Control is not accessibility-activatable: {node.get_name()}")
    action.do_action(0)


def main():
    if getpass.getuser() != "flatpak-test":
        raise SystemExit("Run only as the disposable ISO test account")
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{os.getuid()}/bus"
    os.environ["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
    os.environ["WAYLAND_DISPLAY"] = "wayland-0"
    os.environ["GDK_BACKEND"] = "wayland"
    for _ in range(120):
        if Path(os.environ["XDG_RUNTIME_DIR"], "wayland-0").exists():
            break
        time.sleep(1)
    else:
        raise SystemExit("GNOME Wayland session did not become available")
    if "--install" in sys.argv:
        install_through_bazaar()
        return
    subprocess.run(["flatpak", "kill", "org.gnome.gitlab.somas.Apostrophe"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Repeated harness runs must not restore a growing set of autosaved windows
    # left by prior forced VM shutdowns. This is a disposable test account.
    shutil.rmtree(Path.home() / ".var/app/org.gnome.gitlab.somas.Apostrophe", ignore_errors=True)
    document = Path.home() / "Documents/flatpak-offline.md"
    document.parent.mkdir(exist_ok=True)
    document.write_text("# Offline ISO test\n\nApostrophe was delivered without networking.\n")
    # systemd manages the applications after this SSH check exits; the VM is
    # disposable and powered off by the surrounding harness.
    for unit, command in (
        ("flatpak-test-bazaar", ["/usr/bin/bazaar-daemon"]),
        ("flatpak-test-apostrophe", ["/usr/bin/flatpak", "run", "--system",
                                     "org.gnome.gitlab.somas.Apostrophe", str(document)]),
    ):
        subprocess.run(["systemd-run", "--user", "--collect", f"--unit={unit}",
                        "--setenv=WAYLAND_DISPLAY=wayland-0", "--setenv=GDK_BACKEND=wayland",
                        *command], check=True)
    Atspi.init()
    wait_for_window("Bazaar")
    window = wait_for_window("Apostrophe", "flatpak-offline")
    text = "# Offline ISO test\n\nEdited and saved through Apostrophe without networking.\n"
    if not editor(window).get_editable_text_iface().set_text_contents(text):
        raise SystemExit("Apostrophe did not accept editing through accessibility")
    time.sleep(2)
    window = wait_for_window("Apostrophe", "flatpak-offline")
    window_action("save")
    for _ in range(30):
        if document.read_text() == text:
            break
        time.sleep(1)
    else:
        raise SystemExit("Apostrophe did not save the edited document")
    print("PASS: edited and saved Markdown through Apostrophe offline", flush=True)
    window_action("preview")
    for _ in range(30):
        if any("document" in node.get_role_name() for node in descendants(window)):
            break
        time.sleep(1)
    else:
        raise SystemExit("Apostrophe's preview document did not appear")
    print("PASS: Apostrophe rendered its Markdown preview offline", flush=True)
    button(window, "Close").get_action_iface().do_action(0)
    time.sleep(2)
    subprocess.run(["systemd-run", "--user", "--collect", "--unit=flatpak-test-apostrophe-reopen",
                    "--setenv=WAYLAND_DISPLAY=wayland-0", "--setenv=GDK_BACKEND=wayland",
                    "flatpak", "run", "--system", "org.gnome.gitlab.somas.Apostrophe", str(document)], check=True)
    reopened = wait_for_window("Apostrophe", "flatpak-offline")
    # GTK's accessibility text interface can expose an empty buffer in preview
    # mode. Check the actual saved bytes and the reopened document window;
    # visual confirmation of the reopened text remains a manual check.
    if document.read_text() != text:
        raise SystemExit("Reopening the document changed the saved bytes")
    button(reopened, "Close").get_action_iface().do_action(0)
    print("PASS: reopened the saved document; persisted edit is unchanged", flush=True)


if __name__ == "__main__":
    main()
