#!/usr/bin/env python3
"""Exercise the actual QML backend using disposable credentials, never print secrets.

Requires Python PySide6 for development testing only; the widget does not use Python.
Run with --live to use the desktop wallet (which may ask for unlock/authorization).
"""

import argparse
import os
from pathlib import Path
import sys
import uuid

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--live", action="store_true", help="write/read/delete a disposable wallet entry")
parser.add_argument("--qml-import-path", type=Path, help="test an extracted distribution QML module instead of the host module")
parser.add_argument("--cleanup", nargs="*", default=[], help="remove specified prototype-test-* entries from earlier failed runs")
parser.add_argument("--cleanup-abandoned", action="store_true", help="remove only UUID-shaped prototype-test entries from earlier runs")
args = parser.parse_args()
if any(not key.startswith("prototype-test-") for key in args.cleanup):
    parser.error("cleanup is restricted to prototype-test-* keys")
if (args.cleanup or args.cleanup_abandoned) and not args.live:
    parser.error("cleanup requires --live")
qInstallMessageHandler(lambda kind, context, message: print(message, flush=True))

app = QGuiApplication(sys.argv[:1])
app.setApplicationName("Bakalari wallet test")
engine = QQmlEngine()
if args.qml_import_path:
    engine.addImportPath(str(args.qml_import_path.resolve()))
component = QQmlComponent(engine)
ui_path = Path(__file__).resolve().parents[1] / "package/contents/ui"
key = "prototype-test-" + uuid.uuid4().hex
engine.rootContext().setContextProperty("testKey", key)
engine.rootContext().setContextProperty("runLive", args.live)
engine.rootContext().setContextProperty("cleanupKeys", args.cleanup)
engine.rootContext().setContextProperty("cleanupAbandoned", args.cleanup_abandoned)
component.setData(r'''
import QtQuick
import "."
Item {
    id: test
    property var wallet: loader.item
    Loader {
        id: loader
        source: "WalletDbus.qml"
        onLoaded: Qt.callLater(test.begin)
        onStatusChanged: if (status === Loader.Error) { test.fail("backend load") }
    }
    function fail(stage) {
        console.error("FAIL: " + stage + "; disposable key: " + testKey)
        Qt.exit(1)
    }
    function cleanup(index) {
        if (index === cleanupKeys.length) { run(); return }
        wallet.deletePassword(cleanupKeys[index], function(error) {
            if (error) { fail("cleanup of previous test"); return }
            cleanup(index + 1)
        })
    }
    function begin() {
        if (!cleanupAbandoned) { cleanup(0); return }
        wallet.withWallet(function(handle) {
            return wallet.call("entryList", "(iss)", [handle, wallet.folder, wallet.applicationId])
        }).then(function(keys) {
            var matches = []
            for (var i = 0; i < keys.length; ++i) {
                var key = String(keys[i])
                if (/^prototype-test-[a-f0-9]{32}$/.test(key)) { matches.push(key) }
            }
            cleanupKeys = matches
            cleanup(0)
        }).catch(function() { fail("abandoned entry cleanup") })
    }
    function run() {
        if (!runLive) {
            console.log("PASS: QML backend imports and constructs")
            Qt.exit(0)
            return
        }
        // Include whitespace, shell syntax, Unicode and a newline; never log it.
        var secret = "  dummy '$() ` ; \\" + "\n" + "Příliš žluťoučký  "
        wallet.savePassword(testKey, secret, function(error) {
            if (error) { fail("store: " + error); return }
            wallet.loadPassword(testKey, function(error, value) {
                var matched = !error && value === secret
                wallet.deletePassword(testKey, function(error) {
                    if (error) { fail("cleanup"); return }
                    if (!matched) { fail("round trip"); return }
                    wallet.loadPassword(testKey, function(error, value) {
                        if (error || value !== "") { fail("read after deletion"); return }
                        wallet.deletePassword(testKey, function(error) {
                            if (error) { fail("idempotent deletion"); return }
                            checkQueuedDeletion(secret)
                        })
                    })
                })
            })
        })
    }
    function checkQueuedDeletion(secret) {
        var saved = false
        wallet.savePassword(testKey, secret, function(error) {
            if (error) { fail("queued save"); return }
            saved = true
        })
        // Enqueue immediately, as logout can occur while a save is still pending.
        wallet.deletePassword(testKey, function(error) {
            if (error || !saved) { fail("queued deletion"); return }
            wallet.loadPassword(testKey, function(error, value) {
                if (error || value !== "") { fail("save/logout race"); return }
                Qt.exit(0)
            })
        })
    }
}
'''.encode("utf-8"), QUrl.fromLocalFile(str(ui_path / "WalletTest.qml")))

engine.exit.connect(app.exit)
if component.isError():
    for error in component.errors():
        print(error.toString(), file=sys.stderr)
    sys.exit(1)
roots = []
def create():
    root = component.create()
    if root is None:
        for error in component.errors():
            print(error.toString(), file=sys.stderr)
        app.exit(1)
    else:
        roots.append(root)

QTimer.singleShot(0, create)
QTimer.singleShot(120000, lambda: (print("FAIL: timed out; disposable key: " + key), app.exit(1)))
result = app.exec()
if result == 0 and args.qml_import_path:
    plugin = args.qml_import_path.resolve() / "org/kde/plasma/workspace/dbus/libdbusplugin.so"
    if str(plugin) not in Path("/proc/self/maps").read_text():
        print("FAIL: the requested distribution plugin was not loaded")
        for line in Path("/proc/self/maps").read_text().splitlines():
            if "libdbusplugin.so" in line:
                print("Loaded plugin: " + line.split()[-1])
                break
        result = 1
    else:
        print("PASS: loaded the requested distribution D-Bus plugin")
if result == 0:
    print("PASS: " + ("live QML wallet round trip, deletion and save/logout ordering" if args.live else "QML backend loads"))
sys.exit(result)
