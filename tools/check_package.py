#!/usr/bin/env python3
"""Check the built release, optionally validating an extracted copy with Omarchy."""
import argparse
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
from zipfile import ZipFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate", action="store_true", help="Also run Omarchy's validator")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    manifest = json.loads((root / "manifest.json").read_text())
    assert manifest["schemaVersion"] == 1
    assert manifest["id"] == "sarr.windowpeek"
    assert manifest["author"] == "Sarr"
    assert manifest["kinds"] == ["bar-widget"]
    archive_path = root / "dist" / ("WindowPeek-" + manifest["version"] + ".zip")
    forbidden = {".git", ".reference", "dist", "__pycache__", "AGENTS.md",
                 "HANDOFF.md", "UX_AGREEMENTS.md", "NEW_CHAT.txt", "install.py"}
    required = {
        "manifest.json", "qmldir", "LICENSE", "README.md", "CHANGELOG.md",
        "vendor/omarchy/LICENSE", "vendor/omarchy/OmarchyLogo.qml",
        "vendor/omarchy/PopupMotion.qml", "vendor/omarchy/WindowPanel.qml",
        "update.py", "wallpaper_contrast.py", "tools/focus_observer.py",
        "FocusIncident.js", "FocusWatch.js", "NativeProtection.js", "SearchFocus.js",
        "FocusRecoveryText.js", "FocusIssues.js", "TextReadability.js",
        "Shortcuts.js", "ShortcutBindings.js", "assets/grain.svg", "assets/grain-tint.svg",
        "docs/UPDATES.md", "docs/GUIDE.md", "docs/README.pl.md", "docs/KNOWN_ISSUES.md",
        "docs/TROUBLESHOOTING.md", "docs/FOCUS_RECOVERY.md",
        "preview.png", "docs/preview-thumbnail.png", "tools/render_artwork.py",
        "tests/artwork/icons/editor.svg", "tests/protocols/virtual-keyboard-unstable-v1.xml",
        "tests/protocols/wlr-virtual-pointer-unstable-v1.xml",
    }
    with ZipFile(archive_path) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)), "Duplicate archive paths"
        assert archive.testzip() is None, "Corrupt archive"
        for info in archive.infolist():
            path = PurePosixPath(info.filename)
            assert not path.is_absolute() and ".." not in path.parts
            assert path.parts[0] == "windowpeek" and len(path.parts) > 1
            assert not set(path.parts) & forbidden, "Private file: " + info.filename
            assert not stat.S_ISLNK(info.external_attr >> 16), "Symlink: " + info.filename
            assert path.name not in {"FrameProbe.qml", "MotionProbe.qml", "test_install.py"}
            source = root.joinpath(*path.parts[1:])
            assert source.is_file() and source.read_bytes() == archive.read(info), "Stale archive: " + info.filename
        assert {p.name for p in map(PurePosixPath, names) if len(p.parts) == 2 and p.suffix == ".py"} == {
            "update.py", "wallpaper_contrast.py"}, "Unexpected root Python worker"
        assert json.loads(archive.read("windowpeek/manifest.json")) == manifest
        version = re.search(r'property string version: "([^"]+)"', archive.read("windowpeek/Runtime.qml").decode())
        assert version and version[1] == manifest["version"], "Runtime/manifest version mismatch"
        releases = re.findall(r"^## ([0-9]+\.[0-9]+\.[0-9]+)$", archive.read("windowpeek/CHANGELOG.md").decode(), re.M)
        assert releases and releases[0] == manifest["version"], "Changelog/manifest version mismatch"
        for entry in manifest["entryPoints"].values():
            path = PurePosixPath(entry)
            assert not path.is_absolute() and ".." not in path.parts
            required.add(entry)
        # The module declaration is the authoritative list of QML components.
        for line in archive.read("windowpeek/qmldir").decode().splitlines():
            fields = line.split()
            if fields and fields[-1].endswith(".qml"):
                required.add(fields[-1])
        assert {"windowpeek/" + name for name in required} <= set(names), "Missing runtime or documentation"
        if args.validate:
            # Validate what users receive, not ignored diagnostics in the worktree.
            with tempfile.TemporaryDirectory(prefix="windowpeek-release-check-") as directory:
                archive.extractall(directory)
                subprocess.run(["omarchy", "plugin", "validate", str(Path(directory) / "windowpeek")], check=True)
    print(f"PASS release {manifest['version']}: {len(names)} files, components, workers, docs, versions and privacy")


if __name__ == "__main__":
    main()
