#!/usr/bin/env python3
"""Build a reproducible source archive from an explicit set of project files."""
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
version = json.loads((root / "manifest.json").read_text())["version"]
# Local Python helpers are not part of the release. Include only runtime workers.
files = [p for p in root.iterdir() if p.is_file() and (
    p.suffix in (".qml", ".js", ".json") or p.name in ("update.py", "wallpaper_contrast.py",
    "README.md", "CHANGELOG.md", "LICENSE", "qmldir", ".gitignore", "preview.png"))]
for directory in ("docs", "tests", "tools", "vendor", "assets", ".github"):
    files.extend(p for p in (root / directory).rglob("*") if p.is_file() and "__pycache__" not in p.parts)
output = root / "dist" / ("WindowPeek-" + version + ".zip")
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        if path.is_symlink():
            raise ValueError("Refusing symlink: " + str(path.relative_to(root)))
        info = zipfile.ZipInfo("windowpeek/" + path.relative_to(root).as_posix(), (2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes())
print(output)
