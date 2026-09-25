#!/usr/bin/env python3
"""Exercise QML with native Qt input in an isolated offscreen profile."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from test_keys import build_keyboard, build_pointer_frame

parser = argparse.ArgumentParser()
parser.add_argument("case", choices=["readability-opening", "window-state", "readability-worker", "bar-readability", "readability-coverage", "text-shadow-visual", "text-shadow", "focus-approval", "settings-visit", "focus-issues", "focus-settings", "input-focus", "logo-cooldown", "logo-playback", "logo-picker-native", "panel-hints-native", "focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "branding", "hover-footprint", "hover-navigation", "hover-navigation-native", "settings-panel-native", "settings-input-native", "settings-input", "wallpaper-contrast-native", "wallpaper-contrast", "shortcuts-native", "shortcuts-editor", "surfaces", "wallpaper-opening", "wallpaper-source", "glass-native", "glass", "preview-keys", "quick-selection", "window-shortcuts", "list-height", "defaults", "row-navigation", "settings-sections", "dropdowns-native", "dropdowns", "navigation", "move-menu", "click-modifiers", "gestures-native", "bar-dismiss", "motion", "background", "timing-native", "bar-return-native", "bar-bridge-native", "panel", "move", "editor", "labels", "actions", "activation", "privacy", "preferences", "widget", "updates", "review", "screenshots", "native", "hints", "hints-native", "preview", "hover", "scrolling", "interaction", "interaction-native", "transition-native", "borders", "borders-native"])
parser.add_argument("--scale", type=float, default=1)
parser.add_argument("--bar-section", choices=["left", "center", "right"], default="center")
parser.add_argument("--image")
parser.add_argument("--style", choices=["bar-return-native", "bar-bridge-native", "panel", "compact"], default="panel")
parser.add_argument("--surface", choices=["preview", "panel"], default="preview")
parser.add_argument("--hints", choices=["on", "off"], default="on")
parser.add_argument("--desktop", action="store_true", help="Use the desktop renderer and Qt style")
parser.add_argument("--software", action="store_true", help="Override only the renderer for a desktop comparison")
parser.add_argument("--compile-only", action="store_true", help="Compile a supported native fixture without mapping windows or sending input")
parser.add_argument("--overlay-menu", action="store_true", help="Reproduce the old overlay-only menu in gestures-native (expected pixel failure)")
parser.add_argument("--row-move-menu", action="store_true", help="Open retained-preview menus from a list row in gestures-native")
parser.add_argument("--log", type=Path, help="Save complete fixture output for diagnosis")
parser.add_argument("--manual", action="store_true", help="Leave interaction-native open for a 75-second manual trace")
parser.add_argument("--placeholder-preview", action="store_true", help="Use a fictional image while testing native preview input")
args = parser.parse_args()
if args.case in ("focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native") and os.environ.get("WINDOWPEEK_ISOLATED") != "1":
    parser.error("This fixture requires a private compositor with fictional windows")
if args.compile_only and args.case not in ("hover-navigation-native", "settings-panel-native", "wallpaper-contrast-native", "shortcuts-native", "wallpaper-opening", "glass-native", "gestures-native"):
    parser.error("--compile-only requires a supported native fixture")
if args.overlay_menu and args.case != "gestures-native":
    parser.error("--overlay-menu requires gestures-native")
if args.row_move_menu and args.case != "gestures-native":
    parser.error("--row-move-menu requires gestures-native")
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="windowpeek-ui #-" if args.case == "focus-approval" else "windowpeek-ui-") as directory:
    profile = Path(directory)
    for name in ("Ui", "Commons"):
        (profile / name).symlink_to(Path("/usr/share/omarchy/shell") / name, target_is_directory=True)
    if args.case in ("focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "panel-hints-native", "logo-picker-native"):
        (profile / "HostBar").symlink_to(Path("/usr/share/omarchy/shell/plugins/bar"), target_is_directory=True)
    if args.placeholder_preview:
        if args.case not in ("focus-protection-cycle-native", "preview-keys", "readability-coverage"):
            parser.error("--placeholder-preview requires a preview fixture")
        plugin = profile / "WindowPeek"
        plugin.mkdir()
        for source in root.iterdir():
            if source.name != "WindowCapture.qml":
                (plugin / source.name).symlink_to(source, target_is_directory=source.is_dir())
        shutil.copyfile(root / "tests/ui/FictionalCapture.qml", plugin / "WindowCapture.qml")
    else:
        (profile / "WindowPeek").symlink_to(root, target_is_directory=True)
    fixture = {"settings-input-native": "settings-input", "dropdowns-native": "dropdowns", "bar-return-native": "bar-return", "bar-bridge-native": "bar-bridge", "hints-native": "hints", "borders-native": "borders"}.get(args.case, args.case)
    shutil.copyfile(root / "tests/ui" / (fixture + ".qml"), profile / "shell.qml")
    shutil.copyfile(root / "tests/ui/FakeHost.qml", profile / "FakeHost.qml")
    if args.case in ("pinned-search-native", "focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native"):
        shutil.copyfile(root / "tests/ui" / ("focus-recovery-receiver.qml" if args.case in ("focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native") else "keyboard-receiver.qml"), profile / "receiver.qml")
    if args.case in ("logo-picker-native", "branding", "settings-panel-native", "hover-navigation-native", "shortcuts-native", "shortcuts-editor", "dropdowns", "dropdowns-native"):
        (profile / "dropdown-wallpaper.svg").write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="520" height="600">
<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#45215e"/><stop offset=".55" stop-color="#d55688"/><stop offset="1" stop-color="#f8c685"/></linearGradient></defs>
<path fill="url(#sky)" d="M0 0h520v600H0z"/><path fill="#533263" d="M0 310L110 280 260 410 420 285 520 300v300H0z"/>
<path fill="#2c1c40" d="M0 410l170-20 240 155 110-140v195H0z"/></svg>''')
    if args.case in ("settings-visit", "branding", "logo-picker-native", "logo-playback", "logo-cooldown"):
        (profile / "animated-logo.gif").write_bytes(base64.b64decode("R0lGODlhEAAEAPAAANiY9QAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACAAAACwAAAAAEAAEAAACB4SPqcvtXQAAIfkEAAgAAAAsAAAAABAABACActuqAAAAAgeEj6nL7V0AACH5BAAIAAAALAAAAAAQAAQAgOGwbQAAAAIHhI+py+1dAAA7"))
    if args.case in ("settings-visit", "branding", "logo-picker-native", "logo-playback", "logo-cooldown"):
        shutil.copyfile(profile / "animated-logo.gif", profile / "logo #1.GIF")
        # Same three frames without the GIF's own loop extension.
        (profile / "single-play-logo.gif").write_bytes((profile / "animated-logo.gif").read_bytes()
            .replace(b"!\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00", b""))
    if args.case in ("text-shadow", "wallpaper-contrast", "wallpaper-contrast-native"):
        for name, rgb in (("bright", "245 235 210"), ("dark", "20 35 40")):
            (profile / (name + ".ppm")).write_text("P3\n1 1\n255\n" + rgb + "\n")
    if args.case == "readability-opening":
        (profile / "purple.ppm").write_text("P3\n1 1\n255\n105 55 125\n")
        (profile / "dark.ppm").write_text("P3\n1 1\n255\n20 35 40\n")
    if args.case == "readability-coverage":
        (profile / "green.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="700"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="#428d72"/><stop offset="1" stop-color="#142d26"/></linearGradient></defs><path fill="url(#g)" d="M0 0h1000v700H0z"/></svg>')
    if args.case == "wallpaper-source":
        for name, color in (("wallpaper A.svg", "#ff0000"), ("wallpaper B.svg", "#0000ff")):
            (profile / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><path fill="{color}" d="M0 0h8v8H0z"/></svg>')
        (profile / "wallpaper link").symlink_to(profile / "wallpaper A.svg")
    if args.case in ("focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "settings-panel-native", "hover-navigation-native", "shortcuts-native", "gestures-native", "bar-return-native"):
        build_keyboard(root, profile)
    if args.case in ("logo-picker-native", "focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "hover-navigation-native", "gestures-native"):
        build_pointer_frame(root, profile)
    native = args.case in ("logo-picker-native", "panel-hints-native", "focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "hover-navigation-native", "settings-panel-native", "settings-input-native", "wallpaper-contrast-native", "shortcuts-native", "dropdowns-native","wallpaper-opening", "glass-native", "gestures-native", "timing-native", "bar-return-native", "bar-bridge-native", "transition-native", "native", "hover", "interaction-native", "hints-native", "borders-native")
    env = dict(os.environ, QT_QPA_PLATFORM="wayland" if native else "offscreen", QT_QPA_PLATFORMTHEME="",
               QT_QUICK_BACKEND="software", QT_QUICK_CONTROLS_STYLE="Basic",
               WINDOWPEEK_TEST_SCALE=str(args.scale), WINDOWPEEK_TEST_IMAGE=args.image or "", WINDOWPEEK_TEST_STYLE=args.style,
               WINDOWPEEK_TEST_SURFACE=args.surface, WINDOWPEEK_TEST_HINTS=args.hints,
               WINDOWPEEK_TEST_MANUAL="1" if args.manual else "",
               WINDOWPEEK_TEST_COMPILE_ONLY="1" if args.compile_only else "")
    env["WINDOWPEEK_TEST_PROFILE"] = str(profile)
    env["WINDOWPEEK_TEST_BAR_SECTION"] = args.bar_section
    if args.case in ("wallpaper-contrast", "wallpaper-contrast-native"):
        env["HOME"] = str(profile / "home")
        theme = profile / "home/.local/state/omarchy/current/theme"
        theme.mkdir(parents=True)
        (theme.parent / "theme.name").write_text("bright-theme")
        (theme / "colors.toml").write_text('background="#1f1f28"\nforeground="#dcd7ba"\n')
        (theme / "shell.toml").write_text("")
    if args.case in ("focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "settings-panel-native", "hover-navigation-native", "shortcuts-native", "gestures-native", "bar-return-native"):
        env["WINDOWPEEK_TEST_KEYBOARD"] = str(profile / "control-key")
    if args.case in ("logo-picker-native", "focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "hover-navigation-native", "gestures-native"):
        env["WINDOWPEEK_TEST_POINTER_FRAME"] = str(profile / "pointer-frame")
        env["WINDOWPEEK_TEST_PIXEL_PROBE"] = str(root / "tools/test_compositor_pixel.py")
        env["WINDOWPEEK_TEST_OVERLAY_MENU"] = "1" if args.overlay_menu else ""
        env["WINDOWPEEK_TEST_ROW_MENU"] = "1" if args.row_move_menu else ""
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
    if args.case in ("focus-notice-native", "focus-close-native", "focus-protection-cycle-native", "focus-geometry-native", "focus-return-native", "focus-click-native", "focus-settings-native", "focus-recovery-native", "hover-stability-native", "pinned-search-native", "outside-wheel-native", "bar-compact-native", "hover-navigation-native", "gestures-native", "timing-native", "bar-return-native", "native", "interaction-native") and not args.manual and not args.compile_only:
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
