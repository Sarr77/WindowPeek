#!/usr/bin/env python3
"""Run offline checks; desktop interaction is deliberately a separate command."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
commands = [
    ["node", "tests/model.test.cjs"],
    ["node", "tests/contracts.test.cjs"],
    [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"],
    [sys.executable, "tools/test_qml.py"],
    [sys.executable, "-B", "tools/test_preferences.py"],
]
for case in ("list-height", "defaults", "row-navigation", "settings-sections", "dropdowns", "navigation", "move-menu", "click-modifiers", "bar-dismiss", "motion", "background", "panel", "move", "editor", "labels", "actions", "activation", "privacy", "preferences", "widget", "updates", "review", "hints", "preview", "scrolling", "interaction", "borders"):
    commands.append([sys.executable, "tools/test_ui.py", case])
commands.append([sys.executable, "tools/test_ui.py", "background", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "defaults", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "list-height", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "panel", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "activation", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "scrolling", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "scrolling", "--surface", "panel"])
commands.append([sys.executable, "tools/test_ui.py", "scrolling", "--surface", "panel", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "interaction", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "hints", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "borders", "--scale", "2"])
commands.append([sys.executable, "tools/test_ui.py", "review", "--scale", "2"])
commands.append(["omarchy", "plugin", "validate", str(root)])
for command in commands:
    result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60)
    if result.returncode:
        print(result.stdout + result.stderr)
        raise SystemExit(result.returncode)
    print("PASS", " ".join(command[1:]), flush=True)
