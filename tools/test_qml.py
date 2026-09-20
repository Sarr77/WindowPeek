#!/usr/bin/env python3
"""Run QML tests offscreen with a disposable profile."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


root = Path(__file__).resolve().parents[1]
runner = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

with tempfile.TemporaryDirectory(prefix="windowpeek-test-") as directory:
    profile = Path(directory)
    env = dict(os.environ)
    for name in ("CONFIG_HOME", "CACHE_HOME", "DATA_HOME", "STATE_HOME", "RUNTIME_DIR"):
        path = profile / name.lower()
        path.mkdir(mode=0o700)
        env["XDG_" + name] = str(path)
    env.update(
        QT_QPA_PLATFORM="offscreen",
        QT_QPA_PLATFORMTHEME="",
        QT_QUICK_BACKEND="software",
        QT_QUICK_CONTROLS_STYLE="Basic",
        QML_DISABLE_DISK_CACHE="1",
    )
    result = subprocess.run(
        [runner, "-input", str(root / "tests")], env=env, cwd=root, timeout=30
    )
    raise SystemExit(result.returncode)
