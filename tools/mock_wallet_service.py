#!/usr/bin/env python3
"""In-memory KWallet protocol fixture. Run only on a private test D-Bus session."""
import os
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

if os.environ.get("BAKALARI_TEST_PRIVATE_BUS") != "1":
    raise SystemExit("Run through test_debian_compat.sh on a private test bus")

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.kde.kwalletd6", bus=bus, do_not_queue=True)
interface = "org.kde.KWallet"


class Wallet(dbus.service.Object):
    def __init__(self):
        super().__init__(bus, "/modules/kwalletd6")
        self.folders = {}

    @dbus.service.method(interface, out_signature="s")
    def networkWallet(self):
        return "test-wallet"

    @dbus.service.method(interface, in_signature="sxs", out_signature="i")
    def open(self, wallet, window, app):
        return 1

    @dbus.service.method(interface, in_signature="ibs", out_signature="i")
    def close(self, handle, force, app):
        return 0

    @dbus.service.method(interface, in_signature="iss", out_signature="b")
    def hasFolder(self, handle, folder, app):
        return folder in self.folders

    @dbus.service.method(interface, in_signature="iss", out_signature="b")
    def createFolder(self, handle, folder, app):
        self.folders.setdefault(folder, {})
        return True

    @dbus.service.method(interface, in_signature="isss", out_signature="b")
    def hasEntry(self, handle, folder, key, app):
        return key in self.folders.get(folder, {})

    @dbus.service.method(interface, in_signature="issss", out_signature="i")
    def writePassword(self, handle, folder, key, password, app):
        self.folders[folder][key] = password
        return 0

    @dbus.service.method(interface, in_signature="isss", out_signature="s")
    def readPassword(self, handle, folder, key, app):
        return self.folders.get(folder, {}).get(key, "")

    @dbus.service.method(interface, in_signature="isss", out_signature="i")
    def removeEntry(self, handle, folder, key, app):
        self.folders.get(folder, {}).pop(key, None)
        return 0


wallet = Wallet()
print("READY", flush=True)
GLib.MainLoop().run()
