#!/usr/bin/env python3
"""Check native thumbnails with disposable, fictional surfaces and restore focus."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from test_keys import build_keyboard, held_keys


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=8).strip()


def query(kind):
    return json.loads(run("hyprctl", "-j", kind))


def evaluate(code):
    assert run("hyprctl", "eval", code) == "ok", "Compositor rejected fixture setup"


def wait(predicate, message, seconds=6):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if result := predicate():
            return result
        time.sleep(.08)
    raise AssertionError(message)


parser = argparse.ArgumentParser()
parser.add_argument("--pointer", action="store_true", help="Move the native cursor; requires idle input")
parser.add_argument("--park-pointer", action="store_true", help="Park and restore the compositor cursor while QtTest drives hover; requires idle input")
parser.add_argument("--scale", type=float, default=1)
parser.add_argument("--instant", action="store_true", help="Use zero preview delay and disable popup animations")
parser.add_argument("--screen", help="Monitor for the fixture; defaults to the focused monitor")
parser.add_argument("--hover-only", action="store_true", help="Check real Qt hover transitions without the longer capture scenarios")
parser.add_argument("--privacy-only", action="store_true", help="Check Shift preview suppression with a virtual keyboard; requires idle input")
parser.add_argument("--frames-only", action="store_true", help="Measure source repaint and capture delivery without pointer scenarios")
parser.add_argument("--image", type=Path, help="Save only the fictional preview card")
args = parser.parse_args()
if args.pointer and args.park_pointer:
    parser.error("--pointer and --park-pointer are mutually exclusive")
if args.frames_only and (args.pointer or args.hover_only or args.privacy_only):
    parser.error("--frames-only cannot be combined with other scenario selectors")
if args.hover_only and args.pointer:
    parser.error("--hover-only uses Qt events and cannot be combined with --pointer")
if args.privacy_only and (args.pointer or args.hover_only):
    parser.error("--privacy-only cannot be combined with --pointer or --hover-only")
root = Path(__file__).resolve().parents[1]
identity = "windowpeek-capture-" + str(os.getpid())
old_cursor = query("cursorpos") if args.pointer or args.park_pointer else None
old_focus = query("activewindow").get("address")
old_monitors = query("monitors")
if args.screen and not any(m["name"] == args.screen for m in old_monitors):
    parser.error("Unknown fixture monitor: " + args.screen)
test_monitor = next(m for m in old_monitors if m["name"] == args.screen) if args.screen else next(m for m in old_monitors if m["focused"])
source_monitor = next((m for m in old_monitors if m["name"] != test_monitor["name"]), test_monitor)
old_windows = {w["address"]: (w["workspace"]["name"], sorted(w.get("grouped", [])), w["monitor"]) for w in query("clients")}


def desktop_state():
    return (query("activewindow").get("address"),
            [(m["id"], m["focused"], m["activeWorkspace"]["id"], m["specialWorkspace"]["id"]) for m in query("monitors")])


with tempfile.TemporaryDirectory(prefix="windowpeek-capture-") as directory:
    profile = Path(directory)
    keyboard = build_keyboard(root, profile)
    (profile / "WindowPeek").symlink_to(root, target_is_directory=True)
    for part in ("Ui", "Commons"):
        (profile / part).symlink_to(Path("/usr/share/omarchy/shell") / part, target_is_directory=True)
    shutil.copyfile(root / "tests/capture.qml", profile / "shell.qml")
    shutil.copyfile(root / "tests/ui/FakeHost.qml", profile / "FakeHost.qml")
    env = dict(os.environ, WINDOWPEEK_CAPTURE_ID=identity, WINDOWPEEK_TEST_SCALE=str(args.scale),
               WINDOWPEEK_TEST_INSTANT="1" if args.instant else "",
               WINDOWPEEK_TEST_SCREEN=test_monitor["name"],
               WINDOWPEEK_TEST_POINTER="1" if args.pointer else "", XDG_STATE_HOME=str(profile / "state"), XDG_CACHE_HOME=str(profile / "cache"))
    with (profile / "runtime.log").open("w") as log:
        shell = subprocess.Popen(["quickshell", "--no-color", "-p", str(profile)], env=env, stdout=log, stderr=subprocess.STDOUT)
        def ipc(method, *arguments):
            return run("quickshell", "-p", str(profile), "ipc", "call", "windowpeek-capture-test", method, *arguments)
        def status():
            return json.loads(ipc("status"))
        def window(address):
            return next(w for w in query("clients") if w["address"] == address)
        def shown():
            return status()["content"] and status()["mapped"]
        def color(expected):
            observed = ""
            def matches():
                nonlocal observed
                raw = ipc("color")
                observed = raw
                return raw and all(abs(a-b) < 8 for a,b in zip(json.loads(raw), expected))
            try:
                wait(matches, "Captured pixels do not match source content")
            except AssertionError:
                print("Expected", expected, "observed", observed)
                if args.image:
                    ipc("save", str(args.image.resolve())); time.sleep(.2)
                raise
        def move_cursor(point):
            evaluate("hl.dispatch(hl.dsp.cursor.move({x=" + str(point["x"]) + ",y=" + str(point["y"]) + "}))")
        def cross():
            if args.pointer:
                start = query("cursorpos"); end = json.loads(ipc("pointerPoint", "card"))
                for i in range(1, 17):
                    move_cursor({k:round(start[k] + (end[k]-start[k])*i/16) for k in ("x","y")})
                    time.sleep(.025)
            ipc("crossToCard")
        def hover():
            if args.pointer: move_cursor(json.loads(ipc("pointerPoint", "outside")))
            ipc("leave")
            wait(lambda: not status()["content"], "Capture buffers retained after leaving")
            if not status()["parentVisible"]:
                ipc("showSurface", status()["surface"]); time.sleep(.2)
            before = desktop_state()
            if args.pointer: move_cursor(json.loads(ipc("pointerPoint", "row")))
            ipc("hover")
            if not args.instant:
                assert not status()["visible"], "Missing hover dwell"
            wait(shown, "No native thumbnail")
            assert status()["rowRequested"], "Preview lost row ownership"
            assert desktop_state() == before, "Capture changed focus or workspace: " + repr((before, desktop_state()))
        try:
            def ready():
                try:
                    return ipc("ping") == "true"
                except subprocess.CalledProcessError:
                    return False
            wait(ready, "Fixture IPC did not open")
            # Create sources away from existing groups. Opening ordinary windows
            # on the user's current workspace can join its active tab group.
            # Keep repaint sources visible on another monitor when available;
            # a fully occluded client may stop submitting frames.
            evaluate("hl.dispatch(hl.dsp.focus({monitor=" + json.dumps(source_monitor["name"]) + "})); "
                     "hl.dispatch(hl.dsp.focus({workspace=" + json.dumps("name:" + identity + "-source") + "}))")
            ipc("createSources")
            address = wait(lambda: next((w["address"] for w in query("clients") if w["title"] == identity), None), "Fixture source did not open")
            sibling = wait(lambda: next((w["address"] for w in query("clients") if w["title"] == identity + "-sibling"), None), "Fixture sibling did not open")
            for source_address in (address, sibling):
                assert set(window(source_address).get("grouped", [])) <= {address, sibling}, "Fixture joined an existing group"
            ipc("configure", address)
            if args.park_pointer:
                # Keep native surface-enter events out of QtTest's synthetic
                # hover path, including when the preview maps beside the list.
                parking = next((m for m in old_monitors if m["name"] != test_monitor["name"]), test_monitor)
                move_cursor({"x": parking["x"] + 2, "y": parking["y"] + 2})
            if args.frames_only:
                ipc("showSurface", "panel"); time.sleep(.2); hover()
                for value, expected in [("#7b52cc", [123,82,204]), ("#28b4c8", [40,180,200])] * 5:
                    before = status()["sourceFrames"]
                    ipc("changeColor", value)
                    wait(lambda: status()["sourceFrames"] > before, "Source did not repaint")
                    color(expected)
                print("PASS ten source repaints delivered to the preview", flush=True)
                raise SystemExit(0)
            if args.privacy_only:
                for surface in ("panel", "hover"):
                    ipc("showSurface", surface); time.sleep(.2)
                    with held_keys(keyboard, "Shift_L"):
                        ipc("hoverRow", "0")
                        wait(lambda: status()["shiftKnown"] and status()["shiftDown"], "Left Shift was not observed before hover")
                        time.sleep(.5)
                        assert not status()["visible"] and not status()["content"], "Private browsing opened a capture"
                    wait(shown, "Releasing Shift did not open the preview")
                    for control in ("Control_L", "Control_R"):
                        with held_keys(keyboard, control):
                            time.sleep(.2)
                            assert status()["shiftKnown"] and not status()["shiftDown"], "Ctrl was mistaken for Shift"
                            assert shown(), "Ctrl alone hid the preview"
                    with held_keys(keyboard, shift="Shift_L"):
                        wait(lambda: status()["shiftDown"] and not status()["visible"], "Ctrl+Shift did not suppress the row preview")
                        ipc("click", "true")
                        wait(lambda: status()["brought"] == address, "Private browsing blocks row Ctrl+Shift+click")
                    # Activation closes the hover overview. Start a fresh view
                    # before testing stationary press/release independently.
                    ipc("showSurface", surface); time.sleep(.2); ipc("hoverRow", "0")
                    wait(shown, "No preview after private row activation")
                    with held_keys(keyboard, "Shift_R"):
                        wait(lambda: status()["shiftDown"], "Right Shift was not observed")
                        wait(lambda: not status()["visible"] and not status()["content"], "Shift did not hide and release an existing capture")
                    wait(shown, "Release did not restart preview")
                    cross()
                    with held_keys(keyboard, shift="Shift_L"):
                        wait(lambda: status()["shiftDown"] and status()["pointerOnCard"], "Shift was not observed on the card")
                        assert shown(), "Shift hid the card under the pointer"
                        ipc("cardClick", "true")
                        wait(lambda: status()["brought"] == address, "Ctrl+Shift+click on the card stopped working")
                    ipc("showSurface", surface); time.sleep(.2); ipc("hoverRow", "0")
                    wait(shown, "No preview for gap test"); cross()
                    with held_keys(keyboard, "Shift_L"):
                        wait(lambda: status()["shiftDown"], "Shift not observed before gap exit")
                        ipc("pauseInGap")
                        wait(lambda: not status()["visible"] and not status()["content"], "Gap incorrectly preserves Shift exception")
                    ipc("parentClose"); time.sleep(.2)
                    print("PASS", surface, "native Shift privacy: both keys, Ctrl does not hide previews, stationary press/release, capture release, row/card Ctrl+Shift+click and gap exit", flush=True)
                output = (profile / "runtime.log").read_text()
                assert not re.search(r"ReferenceError|TypeError|Unable to assign|Binding loop|Error loading", output), output
                for w in query("clients"):
                    if w["address"] in old_windows:
                        assert (w["workspace"]["name"], sorted(w.get("grouped", [])), w["monitor"]) == old_windows[w["address"]]
                raise SystemExit(0)
            if not args.pointer:
                for surface in ("panel", "hover"):
                    ipc("showSurface", surface); time.sleep(.2)
                    for index in (0, 1, 2, 0):
                        expected = ipc("hoverRow", str(index))
                        wait(lambda: status()["mapped"] and status()["address"] == expected,
                             "Hover did not select row " + str(index) + " in " + surface)
                        time.sleep(.15)
                        state = status()
                        assert any(row["address"] == expected and row["hovered"] and row["requested"]
                                   for row in state["rowInput"]), "Opening the preview steals row hover"
                        if surface == "panel":
                            # Preview delay can be zero; the independent text hint
                            # still has its own dwell and must be awaited separately.
                            wait(lambda: any(row["address"] == expected and row["hint"]
                                             for row in status()["rowInput"]),
                                 "Row action hint is missing beside the preview")
                        if index == 0:
                            assert state["titleLines"] == 2 and state["titleTruncated"], "Long preview title does not wrap and elide on two lines"
                            if args.image and surface == "panel":
                                ipc("save", str(args.image.resolve()))
                                wait(args.image.exists, "Preview image not saved")
                    ipc("exitSurface")
                    wait(lambda: not status()["visible"], "Hover preview remains after leaving " + surface)
                    if surface == "panel":
                        ipc("hints", "off"); ipc("hoverRow", "0")
                        wait(lambda: status()["mapped"], "Disabling hints hides the window preview")
                        assert not any(row["hint"] for row in status()["rowInput"]), "Disabled row hints remain visible"
                        ipc("exitSurface")
                        wait(lambda: not status()["visible"], "Preview remains after leaving with hints off")
                        ipc("hints", "on")
                    ipc("showSurface", surface); time.sleep(.2)
                    ipc("hoverRow", "0")
                    wait(lambda: status()["mapped"], "No preview before pointer handoff")
                    ipc("pauseInGap"); time.sleep(1.1)
                    state = status()
                    assert state["mapped"] and state["parentVisible"] and state["cardHovered"] and state["hovered"], "Row hint disrupts the gap handoff"
                    assert not any(row["hint"] for row in state["rowInput"]), "Row hint remains over the preview gap"
                    cross(); ipc("cardClick", "false")
                    assert status()["focused"] == address, "Preview click no longer focuses its window"
                    ipc("parentClose"); time.sleep(.2)
                    print("PASS", surface, "Qt row hover, hints, two-line title, leave and preview handoff", flush=True)
                if args.hover_only:
                    raise SystemExit(0)
            for surface in ("panel", "hover"):
                ipc("showSurface", surface); time.sleep(.2)
                hover(); color([40,180,200])
                ipc("changeColor", "#7b52cc"); color([123,82,204])
                ipc("changeColor", "#28b4c8"); color([40,180,200])
                if args.image and surface == "panel":
                    ipc("save", str(args.image.resolve()))
                    wait(args.image.exists, "Preview image not saved")
                ipc("click", "false")
                wait(lambda: status()["focused"] == address, "Preview prevents row click")
                hover()
                with held_keys(keyboard, shift="Shift_L"):
                    ipc("click", "true")
                    wait(lambda: status()["brought"] == address, "Preview prevents Ctrl+Shift+click")
                hover()
                state = status()
                gap_right = state["origin"]["x"] - (state["listOrigin"]["x"] + state["bounds"]["width"])
                gap_left = state["listOrigin"]["x"] - (state["origin"]["x"] + state["cardWidth"])
                assert min(abs(gap_right - 8*args.scale), abs(gap_left - 8*args.scale)) <= 2, "Preview is not beside the visible panel: " + repr(state)
                assert state["origin"]["y"] >= state["listOrigin"]["y"] - 1, "Preview rises above the visible panel"
                if surface == "panel":
                    assert state["bounds"]["width"] < state["sceneWidth"], "Fixture must use a full-screen parent with a smaller visible card"
                if not args.pointer:
                    ipc("pauseInGap"); time.sleep(1.1)
                    state = status()
                    assert state["mapped"] and state["parentVisible"] and state["cardHovered"] and state["hovered"], "Stationary gap hover closes surfaces or loses row highlight"
                    assert not state["focused"] and not state["brought"], "Invisible gap activates a window"
                cross()
                time.sleep(.65)
                state = status()
                assert state["mapped"] and state["cardHovered"] and state["parentVisible"], "Pointer handoff closes parent or preview"
                ipc("cardClick", "false")
                wait(lambda: status()["focused"] == address and not status()["brought"], "Card click does not focus exact window")
                hover(); cross()
                with held_keys(keyboard, shift="Shift_L"):
                    ipc("cardClick", "true")
                    wait(lambda: status()["brought"] == address and not status()["focused"], "Card Ctrl+Shift+click does not bring exact window")
                hover(); ipc("wheel")
                wait(lambda: status()["scroll"] > 0, "Preview prevents wheel scrolling")
                if not args.pointer:
                    ipc("parentClose"); time.sleep(.2)
                    ipc("edge", "true"); ipc("showSurface", surface); time.sleep(.2)
                    hover(); ipc("pauseInGap"); time.sleep(1.1)
                    state = status()
                    gap_left = state["listOrigin"]["x"] - state["origin"]["x"] - state["cardWidth"]
                    assert abs(gap_left - 8*args.scale) <= 2, "Preview did not flip beside the right-edge panel"
                    assert state["origin"]["y"] >= state["listOrigin"]["y"] - 1, "Flipped preview rises above the visible panel"
                    assert state["mapped"] and state["parentVisible"] and state["hovered"], "Flipped gap does not retain preview and row highlight"
                    ipc("leave")
                    wait(lambda: not status()["content"], "Gap hover is latched after leaving")
                    ipc("parentClose"); time.sleep(.2); ipc("edge", "false")
                print("PASS", surface, "thumbnail: placement, pointer handoff, card click/Ctrl+Shift+click, live frames and wheel", flush=True)
            ipc("showSurface", "hover"); time.sleep(.2); hover()
            ipc("promote"); time.sleep(.3)
            state = status()
            assert state["parentVisible"] and state["mapped"] and state["content"] and state["promotionRetained"], "Promotion replaced the preview owner or capture"
            color([40,180,200])
            print("PASS hover expansion retains the thumbnail owner and live capture", flush=True)
            ipc("showSurface", "panel"); time.sleep(.2)
            # Capture must not summon the source workspace or select an inactive tab.
            for workspace in ("name:" + identity, "special:" + identity):
                evaluate('hl.dispatch(hl.dsp.window.move({window="address:' + address + '",workspace=' + json.dumps(workspace) + ',follow=false}))')
                hover(); color([40,180,200])
                print("PASS hidden", "special" if workspace.startswith("special:") else "ordinary", "workspace capture without focus changes", flush=True)
            evaluate('hl.dispatch(hl.dsp.window.move({window="address:' + sibling + '",workspace="special:' + identity + '",follow=false})); '
                     'hl.dispatch(hl.dsp.group.toggle({window="address:' + address + '"})); '
                     'hl.get_window("address:' + address + '").group:add(hl.get_window("address:' + sibling + '")); '
                     'hl.dispatch(hl.dsp.focus({window="address:' + sibling + '"})); '
                     'hl.get_window("address:' + sibling + '").monitor:set_special_workspace({})')
            group_guard = ('local w=hl.get_window("address:' + address + '"); '
                           'if not w.group or w.group.current ~= hl.get_window("address:' + sibling + '") then error("fixture tab selection changed") end')
            evaluate(group_guard)
            hover(); color([40,180,200])
            evaluate(group_guard)
            print("PASS inactive grouped tab captures its own content", flush=True)
            ipc("leave"); ipc("hints", "auto"); hover()
            assert status()["hintsUsed"] == 99, "Preview without instructions consumes the hint budget"
            hover()
            assert status()["hintsUsed"] == 99, "Repeated preview consumes the hint budget"
            ipc("closeSource")
            wait(lambda: not status()["content"], "Closed window leaves stale capture")
            print("PASS hint budget and source destruction release", flush=True)
            for w in query("clients"):
                if w["address"] in old_windows:
                    assert (w["workspace"]["name"], sorted(w.get("grouped", [])), w["monitor"]) == old_windows[w["address"]]
            output = (profile / "runtime.log").read_text()
            assert not re.search(r"ReferenceError|TypeError|Unable to assign|Binding loop|Error loading|Cannot capture", output), output
            print("PASS existing windows and groups untouched; scale", args.scale, flush=True)
        except Exception as error:
            print((profile / "runtime.log").read_text()[-6000:])
            try: print("Fixture status:", status())
            except subprocess.SubprocessError: pass
            for w in query("clients"):
                if w["title"].startswith(identity):
                    print("Fixture window:", {k:w[k] for k in ("address", "hidden", "floating", "grouped", "workspace")})
            if isinstance(error, subprocess.CalledProcessError):
                print(error.stdout, error.stderr)
            raise
        finally:
            shell.terminate(); shell.wait(timeout=5)
            for monitor in old_monitors:
                if not any(m["name"] == monitor["name"] for m in query("monitors")):
                    continue
                name = monitor["activeWorkspace"]["name"]
                selector = name if name.isdigit() else "name:" + name
                evaluate("hl.dispatch(hl.dsp.focus({monitor=" + json.dumps(monitor["name"]) + "})); "
                         "hl.dispatch(hl.dsp.focus({workspace=" + json.dumps(selector) + "}))")
                special = monitor.get("specialWorkspace", {}).get("name", "")
                value = "{workspace=" + json.dumps(special) + "}" if special else "{}"
                evaluate("hl.get_monitor(" + json.dumps(monitor["name"]) + "):set_special_workspace(" + value + ")")
            if old_focus and any(w["address"] == old_focus for w in query("clients")):
                evaluate('local w=hl.get_window("address:' + old_focus + '"); if w.monitor then hl.dispatch(hl.dsp.focus({monitor=w.monitor.name})) end; '
                         'hl.dispatch(hl.dsp.focus({window="address:' + old_focus + '"}))')
            if old_cursor: move_cursor(old_cursor)
