"""Special and oversized state files must never be read into the shell."""
import json
import importlib.util
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bounded_io.py"


def call(action, path, limit=64, value=None):
    return json.loads(subprocess.run(
        ["/usr/bin/python3", "-I", "-B", str(HELPER), action, str(path), str(limit)],
        input=None if value is None else json.dumps({"text": value}) + "\n",
        text=True, capture_output=True, timeout=2, check=True).stdout)


class BoundedIoTests(unittest.TestCase):
    def test_background_workers_reject_special_files(self):
        def load(name):
            spec = importlib.util.spec_from_file_location(name, ROOT / (name + ".py"))
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module

        updater = load("update")
        wallpaper = load("wallpaper_contrast")
        with tempfile.TemporaryDirectory() as folder:
            fifo = Path(folder) / "special"
            os.mkfifo(fifo)
            with self.assertRaises(ValueError):
                updater.read_local_json(fifo, 64)
            with self.assertRaises(ValueError):
                wallpaper.read_local_text(fifo, 64)
            regular = Path(folder) / "large"
            regular.write_bytes(b"x" * 65)
            with self.assertRaises(ValueError):
                updater.read_local_json(regular, 64)
            with self.assertRaises(ValueError):
                wallpaper.read_local_text(regular, 64)

    def test_regular_file_and_missing_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "state.json"
            self.assertEqual(call("read", path)["status"], "missing")
            self.assertEqual(call("write", path, value='{"value":1}\n')["status"], "ok")
            self.assertEqual(call("read", path)["text"], '{"value":1}\n')
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_special_symlink_and_oversized_files(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            regular = base / "regular"
            regular.write_bytes(b"x" * 65)
            self.assertEqual(call("read", regular)["status"], "error")
            self.assertEqual(call("write", regular, value="x" * 65)["status"], "error")
            self.assertEqual(regular.stat().st_size, 65)
            link = base / "link"
            link.symlink_to(regular)
            self.assertEqual(call("read", link)["status"], "error")
            self.assertEqual(call("write", link, value="ok")["status"], "error")
            self.assertEqual(call("read", base)["status"], "error")
            fifo = base / "fifo"
            os.mkfifo(fifo)
            start = time.monotonic()
            self.assertEqual(call("read", fifo)["status"], "error")
            self.assertLess(time.monotonic() - start, 1)
            self.assertEqual(call("write", fifo, value="ok")["status"], "error")

    def test_invalid_utf8_and_bounded_qml_watcher(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            bad = base / "bad"
            bad.write_bytes(b"\xff")
            self.assertEqual(call("read", bad)["status"], "error")
            fifo = base / "fifo"
            os.mkfifo(fifo)
            for name in ("Ui", "Commons"):
                (base / name).symlink_to(Path("/usr/share/omarchy/shell") / name, target_is_directory=True)
            (base / "WindowPeek").symlink_to(ROOT, target_is_directory=True)
            (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "WindowPeek" as Plugin
ShellRoot {
    Plugin.SafeFile {
        path: Quickshell.env("WINDOWPEEK_SPECIAL_FILE")
        maxBytes: 64; watchChanges: true
        onLoaded: { console.error("UNEXPECTED_LOAD"); Qt.quit(); }
        onLoadFailed: function(reason) { console.info("SAFE_FILE_REJECTED " + reason); Qt.quit(); }
    }
    Timer { interval: 2000; running: true; onTriggered: { console.error("SAFE_FILE_TIMEOUT"); Qt.quit(); } }
}
''')
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       QT_QUICK_CONTROLS_STYLE="Basic", QT_QPA_PLATFORMTHEME="",
                       WINDOWPEEK_SPECIAL_FILE=str(fifo), WAYLAND_DISPLAY="", DISPLAY="",
                       HYPRLAND_INSTANCE_SIGNATURE="", DBUS_SESSION_BUS_ADDRESS="")
            for key in ("CONFIG_HOME", "CACHE_HOME", "DATA_HOME", "RUNTIME_DIR", "STATE_HOME"):
                home = base / key.lower()
                home.mkdir(mode=0o700)
                env["XDG_" + key] = str(home)
            result = subprocess.run(["quickshell", "--no-color", "-p", str(base)],
                                    env=env, text=True, capture_output=True, timeout=5)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("SAFE_FILE_REJECTED error", output)
            self.assertNotIn("UNEXPECTED_LOAD", output)
            self.assertNotIn("SAFE_FILE_TIMEOUT", output)

    def test_watcher_reloads_after_atomic_replacement(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            state = base / "state"
            state.write_text("one")
            for name in ("Ui", "Commons"):
                (base / name).symlink_to(Path("/usr/share/omarchy/shell") / name, target_is_directory=True)
            (base / "WindowPeek").symlink_to(ROOT, target_is_directory=True)
            (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "WindowPeek" as Plugin
ShellRoot {
    Plugin.SafeFile {
        path: Quickshell.env("WINDOWPEEK_SPECIAL_FILE")
        maxBytes: 64; watchChanges: true
        onLoaded: function(content) {
            console.info("SAFE_FILE_READ " + content);
            if (content === "two") Qt.quit();
        }
    }
    Timer { interval: 2000; running: true; onTriggered: { console.error("SAFE_FILE_TIMEOUT"); Qt.quit(); } }
}
''')
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       QT_QUICK_CONTROLS_STYLE="Basic", QT_QPA_PLATFORMTHEME="",
                       WINDOWPEEK_SPECIAL_FILE=str(state), WAYLAND_DISPLAY="", DISPLAY="",
                       HYPRLAND_INSTANCE_SIGNATURE="", DBUS_SESSION_BUS_ADDRESS="")
            for key in ("CONFIG_HOME", "CACHE_HOME", "DATA_HOME", "RUNTIME_DIR", "STATE_HOME"):
                home = base / key.lower()
                home.mkdir(mode=0o700)
                env["XDG_" + key] = str(home)
            with subprocess.Popen(["quickshell", "--no-color", "-p", str(base)], env=env,
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as process:
                prefix = b""
                deadline = time.monotonic() + 3
                while b"SAFE_FILE_READ one" not in prefix and time.monotonic() < deadline:
                    ready, _, _ = select.select([process.stdout], [], [], max(0, deadline - time.monotonic()))
                    if not ready:
                        break
                    prefix += os.read(process.stdout.fileno(), 4096)
                self.assertIn(b"SAFE_FILE_READ one", prefix)
                replacement = base / "replacement"
                replacement.write_text("two")
                replacement.replace(state)
                remainder, _ = process.communicate(timeout=5)
                output = prefix.decode(errors="replace") + remainder
                self.assertEqual(process.returncode, 0, output)
                self.assertIn("SAFE_FILE_READ one", output)
                self.assertIn("SAFE_FILE_READ two", output)
                self.assertNotIn("SAFE_FILE_TIMEOUT", output)


if __name__ == "__main__":
    unittest.main()
