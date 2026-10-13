#!/usr/bin/env python3
"""Check installation without qtpaths6 or build tools on PATH."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NoCompileInstall(unittest.TestCase):
    def setUp(self):
        (ROOT / "build").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "build")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        for command in ["bash", "dirname", "mkdir", "tar", "rm", "rmdir"]:
            (self.bin / command).symlink_to(shutil.which(command))
        self.module_root = self.base / "usr/lib/x86_64-linux-gnu/qt6/qml"
        module = self.module_root / "org/kde/plasma/workspace/dbus/qmldir"
        module.parent.mkdir(parents=True)
        module.write_text("module org.kde.plasma.workspace.dbus\n")
        self.target = self.base / "installed"
        self.env = {**os.environ, "PATH": str(self.bin), "QML_IMPORT_PATH": str(self.module_root)}

    def install(self, version, script="install.sh"):
        shell = self.bin / "plasmashell"
        shell.write_text("#!/bin/sh\nprintf '%s\\n' 'plasmashell " + version + "'\n")
        shell.chmod(0o755)
        return subprocess.run(["/bin/bash", str(ROOT / script),
                               "--destination", str(self.target)], env=self.env,
                              text=True, capture_output=True)

    def test_debian_63_without_development_tools(self):
        result = self.install("6.3.6")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.target / "contents/ui/WalletDbus.qml").is_file())
        plugin = self.target / "contents/ui/BakalariWallet/libbakalarwalletplugin.so"
        plugin.parent.mkdir(parents=True, exist_ok=True)
        plugin.write_bytes(b"obsolete plugin")
        (plugin.parent / "qmldir").write_text("plugin bakalarwalletplugin\n")
        (self.target / "contents/ui/WalletLegacy.qml").write_text("old adapter")
        unrelated = self.target / "keep.txt"
        unrelated.write_text("keep me")
        result = self.install("6.3.6", "update.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(plugin.parent.exists())
        self.assertFalse((self.target / "contents/ui/WalletLegacy.qml").exists())
        self.assertEqual(unrelated.read_text(), "keep me")
        self.assertFalse((self.target / "contents/data").exists())

    def test_old_installer_name_remains_an_alias(self):
        result = self.install("6.3.6", "install-no-compile.sh")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_plasma5_rejected_before_install(self):
        result = self.install("5.27.12")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.exists())

    def test_older_plasma6_rejected_before_install(self):
        result = self.install("6.2.5")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.exists())

    def test_unknown_version_rejected(self):
        result = self.install("unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.exists())


if __name__ == "__main__":
    unittest.main()
