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
parser.add_argument("--motion-only", action="store_true", help="Measure source and preview frame delivery with continuous motion")
parser.add_argument("--startup-only", action="store_true", help="Measure initial preview frames for visible and hidden fictional sources")
parser.add_argument("--startup-source", choices=("wayland", "xcb"), default="wayland", help="Backend of the separate startup-test source")
parser.add_argument("--geometry-only", action="store_true", help="Check live landscape/portrait resize and preview backing options")
parser.add_argument("--frames-only", action="store_true", help="Measure source repaint and capture delivery without pointer scenarios")
parser.add_argument("--image", type=Path, help="Save only the fictional preview card")
args = parser.parse_args()
if args.pointer and args.park_pointer:
    parser.error("--pointer and --park-pointer are mutually exclusive")
if (args.frames_only or args.geometry_only or args.motion_only or args.startup_only) and (args.pointer or args.hover_only or args.privacy_only):
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
    if args.startup_only:
        env["WINDOWPEEK_EXTERNAL_SOURCE"] = "1"
    external_source = None
    external_log = (profile / "source.log").open("w")
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
            if args.startup_only:
                external_source = subprocess.Popen(["qml6",str(root / "tests/startup-source.qml"),"--",identity],
                    env=dict(env,QT_QPA_PLATFORM=args.startup_source,QT_FORCE_STDERR_LOGGING="1"),stdout=external_log,stderr=subprocess.STDOUT)
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
            if args.startup_only:
                ipc("startMotion")
                for state_name in ("visible", "hidden-tab"):
                    if state_name == "hidden-tab":
                        evaluate('hl.dispatch(hl.dsp.group.toggle({window="address:' + address + '"})); '
                                 'hl.get_window("address:' + address + '").group:add(hl.get_window("address:' + sibling + '")); '
                                 'hl.dispatch(hl.dsp.focus({window="address:' + sibling + '"}))')
                        group_guard=('local w=hl.get_window("address:' + address + '"); '
                                     'if not w.group or w.group.current ~= hl.get_window("address:' + sibling + '") then error("fixture tab selection changed") end')
                        evaluate(group_guard)
                    for surface in ("panel", "hover"):
                        ipc("showSurface",surface)
                        time.sleep(1.2)
                        before=desktop_state()
                        ipc("armStartup"); ipc("hover")
                        time.sleep(2.5)
                        samples=json.loads(ipc("startupResult"))
                        source_times=[int(t) for t in re.findall(r"SOURCE_FRAME (\d+)",(profile / "source.log").read_text())]
                        samples["source"]=[t-samples["startedAt"] for t in source_times if samples["startedAt"] <= t <= samples["startedAt"]+2500]
                        if state_name == "visible":
                            assert len(samples["source"])>10, "Separate source frame log is unavailable or source is not animating"
                        def summary(times):
                            gaps=[b-a for a,b in zip(times,times[1:])]
                            return {"first_ms":times[0] if times else None,"count":len(times),
                                    "first_12_ms":times[:12],"max_gap_ms":max(gaps,default=0)}
                        print(json.dumps({"state":state_name,"surface":surface,"scale":args.scale,"backend":args.startup_source,"started_at":samples["startedAt"],
                            "events":samples["events"],"source":summary(samples["source"]),
                            "preview":summary(samples["preview"])}),flush=True)
                        assert samples["preview"], "Startup preview never appeared"
                        assert desktop_state()==before, "Capture changed focus or workspace"
                        if state_name == "hidden-tab": evaluate(group_guard)
                        ipc("leave"); ipc("parentClose")
                        wait(lambda: not status()["content"],"Capture retained after startup trial")
                ipc("stopMotion")
                output=(profile / "runtime.log").read_text()
                assert not re.search(r"ReferenceError|TypeError|Unable to assign|Binding loop|Error loading|Cannot capture",output),output
                for w in query("clients"):
                    if w["address"] in old_windows:
                        assert (w["workspace"]["name"],sorted(w.get("grouped",[])),w["monitor"])==old_windows[w["address"]]
                raise SystemExit(0)
            if args.motion_only:
                ipc("showSurface","hover"); time.sleep(.2); hover()
                ipc("startMotion"); time.sleep(5)
                frames=json.loads(ipc("stopMotion"))
                def timing(samples):
                    samples=samples[5:]
                    gaps=sorted(b-a for a,b in zip(samples,samples[1:]))
                    return {"frames":len(samples),"fps":round((len(samples)-1)*1000/(samples[-1]-samples[0]),1),
                            "p95_ms":gaps[int((len(gaps)-1)*.95)],"max_ms":max(gaps)} if len(samples)>5 else {"frames":len(samples)}
                print(json.dumps({k:timing(v) for k,v in frames.items()}),flush=True)
                assert len(frames["preview"]) > 30, "Preview is not delivering continuous frames"
                output=(profile / "runtime.log").read_text()
                assert not re.search(r"ReferenceError|TypeError|Unable to assign|Binding loop|Error loading|Cannot capture",output),output
                raise SystemExit(0)
            if args.geometry_only:
                evaluate('hl.dispatch(hl.dsp.window.float({window="address:' + address + '",action="set"}))')
                for surface in ("panel", "hover"):
                    ipc("showSurface", surface); time.sleep(.2); hover()
                    ipc("previewOptions", "false", "true")
                    wait(lambda: status()["imageBackingAlpha"] == 0 and status()["frameSizeLocked"], "Preview backing/initial fitted size did not settle")
                    header_height=status()["height"]
                    ipc("previewTitle","Short title"); time.sleep(.08)
                    assert abs(status()["height"]-header_height)<1, "Shortened live title changes frame height"
                    ipc("previewTitle","Fictional document — workspace navigation and thumbnail layout review, with further details beyond the second line")
                    assert abs(status()["height"]-header_height)<1, "Wrapped live title changes frame height"
                    for width,height in ((800,450),(320,640),(900,300)):
                        baseline = status()
                        evaluate('hl.dispatch(hl.dsp.window.resize({window="address:' + address + '",x=' + str(width) + ',y=' + str(height) + ',relative=false}))')
                        def fitted():
                            state = status()
                            if not state["content"] or state["captureHeight"] <= 0: return False
                            ratio = state["captureWidth"] / state["captureHeight"]
                            return abs(ratio-width/height) < .02 and abs(state["fittedWidth"]/state["fittedHeight"]-ratio)<.002 \
                                and abs(state["viewWidth"]-state["fittedWidth"]) < 1 and abs(state["viewHeight"]-state["fittedHeight"]) < 1
                        wait(lambda: status()["captureHeight"] > 0 and abs(status()["captureWidth"]/status()["captureHeight"]-width/height)<.02,
                             "Source capture did not resize")
                        stable = status()
                        assert abs(stable["fittedWidth"]-baseline["fittedWidth"])<1 and abs(stable["fittedHeight"]-baseline["fittedHeight"])<1, "Open preview changes its fitted image area"
                        assert abs(stable["cardWidth"]-baseline["cardWidth"])<1 and abs(stable["height"]-baseline["height"])<1, "Open preview frame moves while the source resizes"
                        hover()
                        wait(fitted,"Reopened preview does not fit current source proportions")
                        state = status()
                        assert state["width"] <= test_monitor["width"] and state["height"] <= test_monitor["height"], state
                        if args.image:
                            destination=args.image.with_name(args.image.stem+'-'+surface+'-'+str(width)+'x'+str(height)+args.image.suffix)
                            ipc("save",str(destination)); wait(destination.exists,"Preview screenshot not saved")
                    ipc("previewOptions","true","false")
                    wait(lambda: status()["imageBackingAlpha"] == 1 and abs(status()["fittedHeight"]-164)<1,
                         "Fixed frame and dark backing cannot be restored")
                    print("PASS",surface,"stable open frame, proportions on reopen and optional backing; scale",args.scale,flush=True)
                output=(profile / "runtime.log").read_text()
                assert not re.search(r"ReferenceError|TypeError|Unable to assign|Binding loop|Error loading|Cannot capture",output),output
                for w in query("clients"):
                    if w["address"] in old_windows:
                        assert (w["workspace"]["name"], sorted(w.get("grouped", [])), w["monitor"]) == old_windows[w["address"]]
                raise SystemExit(0)
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
            for compact in (True, False, True, False):
                ipc("resizeCompact", "true" if compact else "false"); time.sleep(.3)
            frames = json.loads(ipc("finishResizeTrace"))
            assert len(frames) >= 5, "No animation frame evidence"
            assert all(f["mapped"] and f["retained"] and f["shared"] for f in frames), "Resize replaced or hid shared live preview"
            assert max(f["gapError"] for f in frames) <= 1.5, "Preview drifted from animated panel edge"
            if not args.instant:
                assert len({round(f["width"]) for f in frames}) >= 5, "Resize did not exercise intermediate widths"
            print("PASS expand/collapse retains live capture and shared surface; preview gap stable in every sampled frame", flush=True)
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
            if external_source:
                external_source.terminate(); external_source.wait(timeout=5)
            external_log.close()
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
