#!/usr/bin/env python3
"""Render the artwork's fictional windows with WindowPeek's QML controls."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ARTWORK = ROOT / "tests/artwork"


def render(prefix):
    prefix = prefix.resolve()
    prefix.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="windowpeek-artwork-") as directory:
        profile = Path(directory)
        for name in ("Ui", "Commons"):
            (profile / name).symlink_to(Path("/usr/share/omarchy/shell") / name)
        (profile / "WindowPeek").symlink_to(ROOT)
        shutil.copyfile(ARTWORK / "FictionalEditor.qml", profile / "FictionalEditor.qml")
        shutil.copyfile(ROOT / "tests/ui/FakeHost.qml", profile / "FakeHost.qml")
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
                   QT_QUICK_BACKEND="software", QT_QUICK_CONTROLS_STYLE="Basic",
                   WINDOWPEEK_TEST_SCALE="2")
        for name in ("STATE", "CONFIG", "CACHE", "DATA", "RUNTIME"):
            path = profile / name
            path.mkdir(mode=0o700)
            env["XDG_" + name + ("_DIR" if name == "RUNTIME" else "_HOME")] = str(path)
        applications = profile / "DATA/applications"
        applications.mkdir()
        for app_id, name, icon in (
            ("code", "Editor", "editor"),
            ("windowpeek-example-notes", "Notes", "notes"),
            ("chromium", "Browser", "browser"),
            ("foot", "Terminal", "terminal"),
            ("windowpeek-example-music", "Music", "music"),
        ):
            (applications / (app_id + ".desktop")).write_text(
                "[Desktop Entry]\nType=Application\nName=" + name
                + "\nExec=true\nIcon=" + str(ARTWORK / "icons" / (icon + ".svg"))
                + "\nStartupWMClass=" + app_id + "\n")
        fixtures = ((ROOT / "tests/ui/screenshots.qml", str(prefix)),
                    (ARTWORK / "thumbnail.qml", str(prefix) + "-thumbnail.png"))
        for fixture, image in fixtures:
            shutil.copyfile(fixture, profile / "shell.qml")
            result = subprocess.run(["quickshell", "--no-color", "-p", str(profile)],
                env=dict(env, WINDOWPEEK_TEST_IMAGE=image),
                capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            if result.returncode or "WINDOWPEEK_TEST_PASS" not in output:
                raise RuntimeError(output)
    for suffix in ("panel", "hover", "thumbnail"):
        print(str(prefix) + "-" + suffix + ".png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-prefix", type=Path, required=True)
    render(parser.parse_args().output_prefix)
