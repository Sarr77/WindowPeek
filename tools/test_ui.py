#!/usr/bin/env python3
"""Exercise QML with native Qt input in an isolated offscreen profile."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from test_keys import build_keyboard, build_pointer_frame

parser = argparse.ArgumentParser()
parser.add_argument("case", choices=["preview-keys", "window-shortcuts", "list-height", "defaults", "row-navigation", "settings-sections", "dropdowns", "navigation", "move-menu", "click-modifiers", "gestures-native", "bar-dismiss", "motion", "background", "timing-native", "bar-return-native", "bar-bridge-native", "panel", "move", "editor", "labels", "actions", "activation", "privacy", "preferences", "widget", "updates", "review", "screenshots", "native", "hints", "hints-native", "preview", "hover", "scrolling", "interaction", "interaction-native", "transition-native", "borders", "borders-native"])
parser.add_argument("--scale", type=float, default=1)
parser.add_argument("--image")
parser.add_argument("--style", choices=["bar-return-native", "bar-bridge-native", "panel", "compact"], default="panel")
parser.add_argument("--surface", choices=["preview", "panel"], default="preview")
parser.add_argument("--hints", choices=["on", "off"], default="on")
parser.add_argument("--desktop", action="store_true", help="Use the desktop renderer and Qt style")
parser.add_argument("--software", action="store_true", help="Override only the renderer for a desktop comparison")
parser.add_argument("--compile-only", action="store_true", help="Compile gestures-native without mapping windows or sending input")
parser.add_argument("--overlay-menu", action="store_true", help="Reproduce the old overlay-only menu in gestures-native (expected pixel failure)")
parser.add_argument("--log", type=Path, help="Save complete fixture output for diagnosis")
parser.add_argument("--manual", action="store_true", help="Leave interaction-native open for a 75-second manual trace")
args = parser.parse_args()
if args.compile_only and args.case != "gestures-native":
    parser.error("--compile-only requires gestures-native")
if args.overlay_menu and args.case != "gestures-native":
    parser.error("--overlay-menu requires gestures-native")
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="windowpeek-ui-") as directory:
    profile = Path(directory)
    for name in ("Ui", "Commons"):
        (profile / name).symlink_to(Path("/usr/share/omarchy/shell") / name, target_is_directory=True)
    (profile / "WindowPeek").symlink_to(root, target_is_directory=True)
    fixture = {"bar-return-native": "bar-return", "bar-bridge-native": "bar-bridge", "hints-native": "hints", "borders-native": "borders"}.get(args.case, args.case)
    shutil.copyfile(root / "tests/ui" / (fixture + ".qml"), profile / "shell.qml")
    shutil.copyfile(root / "tests/ui/FakeHost.qml", profile / "FakeHost.qml")
    if args.case in ("gestures-native", "bar-return-native"):
        build_keyboard(root, profile)
    if args.case == "gestures-native":
        build_pointer_frame(root, profile)
    native = args.case in ("gestures-native", "timing-native", "bar-return-native", "bar-bridge-native", "transition-native", "native", "hover", "interaction-native", "hints-native", "borders-native")
    env = dict(os.environ, QT_QPA_PLATFORM="wayland" if native else "offscreen", QT_QPA_PLATFORMTHEME="",
               QT_QUICK_BACKEND="software", QT_QUICK_CONTROLS_STYLE="Basic",
               WINDOWPEEK_TEST_SCALE=str(args.scale), WINDOWPEEK_TEST_IMAGE=args.image or "", WINDOWPEEK_TEST_STYLE=args.style,
               WINDOWPEEK_TEST_SURFACE=args.surface, WINDOWPEEK_TEST_HINTS=args.hints,
               WINDOWPEEK_TEST_MANUAL="1" if args.manual else "")
    if args.case in ("gestures-native", "bar-return-native"):
        env["WINDOWPEEK_TEST_KEYBOARD"] = str(profile / "control-key")
    if args.case == "gestures-native":
        env["WINDOWPEEK_TEST_POINTER_FRAME"] = str(profile / "pointer-frame")
        env["WINDOWPEEK_TEST_PIXEL_PROBE"] = str(root / "tools/test_compositor_pixel.py")
        env["WINDOWPEEK_TEST_OVERLAY_MENU"] = "1" if args.overlay_menu else ""
        env["WINDOWPEEK_TEST_COMPILE_ONLY"] = "1" if args.compile_only else ""
    if args.manual and args.case != "interaction-native":
        parser.error("--manual requires interaction-native")
    if args.desktop:
        if not native:
            parser.error("--desktop requires a native fixture")
        for key in ("QT_QPA_PLATFORMTHEME", "QT_QUICK_BACKEND", "QT_QUICK_CONTROLS_STYLE"):
            if key in os.environ:
                env[key] = os.environ[key]
            else:
                env.pop(key, None)
        env["QSG_INFO"] = "1"
    if args.software:
        env["QT_QUICK_BACKEND"] = "software"
    for key in ("STATE_HOME", "CONFIG_HOME", "CACHE_HOME", "DATA_HOME", "RUNTIME_DIR"):
        if key == "RUNTIME_DIR" and native:
            continue
        path = profile / key.lower()
        path.mkdir(mode=0o700)
        env["XDG_" + key] = str(path)
    def check(scenario=""):
        try:
            result = subprocess.run(["quickshell", "--no-color", "-p", str(profile)],
                                    env=dict(env, WINDOWPEEK_PREFERENCES_CASE=scenario),
                                    capture_output=True, text=True, timeout=90 if args.manual else 30)
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b'').decode(errors='replace') + (error.stderr or b'').decode(errors='replace')
            if args.log:
                args.log.write_text(output)
            raise AssertionError('Fixture timed out:\n' + output[-6000:]) from error
        output = result.stdout + result.stderr
        if args.log:
            args.log.write_text(output)
        output = "\n".join(line for line in output.splitlines() if "OpenType support missing" not in line)
        passed = result.returncode == 0 and "WINDOWPEEK_TEST_PASS" in output
        passed = passed and not re.search(r"WINDOWPEEK_TEST_FAIL|ReferenceError|TypeError|RangeError|Unable to assign|Binding loop|Error loading|Column will not function", output)
        if not passed:
            if native:
                output += "\nCursor after test: " + subprocess.check_output(["hyprctl", "-j", "cursorpos"], text=True)
            raise AssertionError(output)
        print("PASS", args.case, scenario, "scale", args.scale)

    cursor = None
    if args.case in ("gestures-native", "timing-native", "bar-return-native", "native", "interaction-native") and not args.manual and not args.compile_only:
        cursor = json.loads(subprocess.check_output(["hyprctl", "-j", "cursorpos"], text=True))
    try:
        check()
    finally:
        if cursor is not None:
            subprocess.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x="
                            + str(int(cursor['x'])) + ",y=" + str(int(cursor['y'])) + "}))"],
                           check=True, capture_output=True, text=True, timeout=5)
    if args.case == "preferences":
        state = Path(env["XDG_STATE_HOME"]) / "windowpeek"
        file = state / "preferences.json"
        assert state.stat().st_mode & 0o777 == 0o700
        assert "id" not in json.loads(file.read_text())["settings"]
        check("restore")
        good = file.read_bytes()
        file.write_text("{invalid json")
        check("corrupt")
        assert file.read_text() == "{invalid json"
        file.write_bytes(good)
        state.chmod(0o500)
        try:
            check("readonly")
            assert file.read_bytes() == good
        finally:
            state.chmod(0o700)
