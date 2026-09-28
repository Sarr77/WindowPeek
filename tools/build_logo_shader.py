#!/usr/bin/env python3
"""Build the bundled reveal shader offline; never invoked by the plugin."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
qsb = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"
source = root / "assets/shaders/logo-reveal.frag"
subprocess.run([qsb, "--qt6", "--qsbversion", "64", "-o", str(source) + ".qsb", str(source)], check=True)
