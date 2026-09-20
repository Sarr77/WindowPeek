#!/usr/bin/env python3
"""Verify focus and moves using disposable windows; restore the desktop afterward."""
import argparse
from contextlib import ExitStack
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from test_keys import build_keyboard, build_pointer_frame, held_keys


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=8).strip()


def query(name):
    return json.loads(run("hyprctl", "-j", name))


def evaluate(code):
    result = run("hyprctl", "eval", code)
    if result != "ok":
        raise AssertionError("Compositor rejected test operation: " + result)


def wait(predicate, message, seconds=6):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        result = predicate()
        if result:
            return result
        time.sleep(0.08)
    raise AssertionError(message)


def selector(workspace):
    name = workspace["name"]
    return name if name.isdigit() or name.startswith("special:") else "name:" + name


parser = argparse.ArgumentParser()
parser.add_argument("--installed", action="store_true", help="Also exercise the installed WindowPeek bar widget")
parser.add_argument("--window-shortcuts", action="store_true", help="Only test Ctrl+digit window and group-tab navigation at both scales")
parser.add_argument("--held-shortcuts", action="store_true", help="Test Ctrl held before opening hover/search with native virtual-keyboard digits")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
identity = "windowpeek-test-" + str(os.getpid())
source = "WindowPeek-Test-" + str(os.getpid())
destination = source + "-Destination"
monitors = query("monitors")
initial_focus = query("activewindow").get("address")
initial_cursor = query("cursorpos")
initial_windows = {w["address"]: (w["workspace"]["name"], sorted(w.get("grouped", [])), w.get("monitor")) for w in query("clients")}


def windows():
    return [w for w in query("clients") if w["class"] == identity]


def window(address):
    return next((w for w in windows() if w["address"] == address), None)


with tempfile.TemporaryDirectory(prefix="windowpeek-native-") as directory:
    config = Path(directory)
    keyboard = build_keyboard(root, config)
    pointer_frame = build_pointer_frame(root, config) if args.held_shortcuts else None
    (config / "WindowPeek").symlink_to(root, target_is_directory=True)
    for name in ("Ui", "Commons"):
        (config / name).symlink_to(Path("/usr/share/omarchy/shell") / name, target_is_directory=True)
    shutil.copyfile(root / "tests/live.qml", config / "shell.qml")
    env = dict(os.environ, XDG_STATE_HOME=str(config / "state"), XDG_CACHE_HOME=str(config / "cache"))
    with (config / "runtime.log").open("w") as log:
        shell = subprocess.Popen(["quickshell", "--no-color", "-p", str(config)], env=env, stdout=log, stderr=subprocess.STDOUT)
        def ipc(method, *args):
            return run("quickshell", "-p", str(config), "ipc", "call", "windowpeek-test", method, *args)
        def status():
            try:
                return json.loads(ipc("status"))
            except (subprocess.SubprocessError, ValueError):
                return {}
        def action(method, address, target=None, expected_error=""):
            assert window(address), "Refusing to act on a non-test window"
            ipc("refresh")
            wait(lambda: ipc("isTestWindow", address) == "true", "Test window not inventoried")
            args = [address] + ([target] if target else [])
            assert ipc(method, *args) == "true", "Action refused"
            wait(lambda: status().get("busy") is False, "Action did not complete")
            assert status().get("error") == expected_error, "Unexpected action error: " + str(status().get("error"))
        def hover_focus(address):
            before = query("activewindow").get("address")
            ipc("hoverOpen")
            wait(lambda: status().get("hoverVisible"), "Hover did not open")
            assert query("activewindow").get("address") == before, "Opening hover took application focus"
            wait(lambda: ipc("hoverClick", address) == "true", "Test row missing from hover")
            try:
                wait(lambda: query("activewindow").get("address") == address
                     and not status().get("hoverBusy") and not status().get("hoverVisible"),
                     "Hover click did not close popup and focus exact window")
            except AssertionError:
                print("Hover diagnostic:", status(), "targetFocused:", query("activewindow").get("address") == address, flush=True)
                print((config / "runtime.log").read_text()[-5000:], flush=True)
                raise
            assert not status().get("hoverError"), "Hover action failed"
        def ctrl_click(address, monitor_name, panel=False):
            assert window(address), "Refusing to click a non-test window"
            assert ipc("selectMonitor", monitor_name) == "true"
            wait(lambda: status().get("screen") == monitor_name, "Fixture did not select the target monitor")
            ipc("panelOpen" if panel else "hoverOpen")
            wait(lambda: status().get("panelOpen" if panel else "hoverVisible"), "Click surface did not open")
            with held_keys(keyboard, shift="Shift_L"):
                wait(lambda: ipc("panelBringClick" if panel else "hoverBringClick", address) == "true", "Ctrl+Shift+click target is missing")
                wait(lambda: status().get("hoverClickDelivered") and not status().get("hoverBusy"), "Ctrl+Shift+click did not complete")
                assert not status().get("hoverError"), "Ctrl+Shift+click error: " + str(status().get("hoverError"))
                wait(lambda: not status().get("panelOpen") and not status().get("hoverVisible"), "Accepted Ctrl+Shift+click must close its surface")
            assert query("activewindow").get("address") == address, "Ctrl+Shift+click did not focus the moved window"
        try:
            wait(lambda: status().get("ready"), "Reader did not get a valid snapshot")
            special_workspace = "special:" + source
            for label, workspace in (("A", "name:" + source), ("B", "name:" + source),
                                     ("C", "name:" + destination), ("D", special_workspace)):
                command = f"foot --app-id={identity} --title=WindowPeek-Test-{label} sleep 180"
                evaluate("hl.dispatch(hl.dsp.exec_cmd(" + json.dumps(command) + ", {workspace = "
                         + json.dumps(workspace + " silent") + ", no_initial_focus = true}))")
            wait(lambda: len(windows()) == 4, "Test windows did not open")
            a, b, c, d = [w["address"] for w in sorted(windows(), key=lambda w: w["title"])]
            assert all(set(w.get("grouped", [])) <= {a, b, c, d} for w in windows())
            if args.window_shortcuts or args.held_shortcuts:
                if len(monitors) > 1:
                    other = next(m for m in monitors if m["id"] != window(c).get("monitor"))
                    evaluate("hl.dispatch(hl.dsp.workspace.move({workspace = " + json.dumps("name:" + destination)
                             + ", monitor = " + json.dumps(other["name"]) + "}))")
                evaluate('hl.dispatch(hl.dsp.focus({window = "address:' + a + '"})); '
                         'hl.dispatch(hl.dsp.group.toggle({window = "address:' + a + '"})); '
                         'hl.get_window("address:' + a + '").group:add(hl.get_window("address:' + b + '"))')
                wait(lambda: set(window(a).get("grouped", [])) == {a, b}, "Test group not created")
                placements = {w["address"]: (w["workspace"]["name"], w["monitor"], sorted(w.get("grouped", []))) for w in windows()}
                for scale in (1, 2):
                    assert ipc("shortcutScale", str(scale)) == "true"
                    if args.held_shortcuts:
                        for view in ("hover", "panel"):
                            for control, target in (("Control_L", b), ("Control_R", c), ("Control_L", d)):
                                with held_keys(keyboard, control) as keys:
                                    ipc("hoverOpen" if view == "hover" else "panelOpen")
                                    wait(lambda: status().get("shortcutControl") and status().get("shortcutFocused") and (status().get("shortcutSurfaceActive") or status().get("previewSurfaceActive")), "Held Ctrl did not reach the opening list")
                                    assert status().get("hoverMode") == (view == "hover"), "Ctrl changed the list mode"
                                    wait(lambda: ipc("shortcutFilter") == "true", "Test rows not ready")
                                    digit = wait(lambda: ipc("shortcutDigit", target), "No visible shortcut label for the test window")
                                    keys.stdin.write("tap " + digit + "\n"); keys.stdin.flush()
                                    wait(lambda: not status().get("panelMapped") and not status().get("hoverBusy"), "Native digit did not close the list")
                                    wait(lambda: query("activewindow").get("address") == target, "Native digit selected the wrong window/tab")
                                    assert not status().get("hoverError"), "Window action failed"
                            print("PASS pre-held left/right Ctrl and native digits in", view, "at scale", scale, flush=True)
                        for before_preview in (True, False):
                            with ExitStack() as pressed:
                                ipc("hoverOpen")
                                wait(lambda: ipc("shortcutFilter") == "true", "Hover test rows not ready")
                                point = json.loads(wait(lambda: ipc("shortcutHoverPoint", b), "Hover row position missing"))
                                if before_preview:
                                    keys = pressed.enter_context(held_keys(keyboard))
                                evaluate("hl.dispatch(hl.dsp.cursor.move({x=" + str(round(point["x"]))
                                         + ",y=" + str(round(point["y"])) + "}))")
                                subprocess.run([str(pointer_frame)], check=True, timeout=3, capture_output=True)
                                wait(lambda: status().get("previewVisible"), "Window preview did not open over the test row")
                                if not before_preview:
                                    keys = pressed.enter_context(held_keys(keyboard))
                                wait(lambda: status().get("shortcutControl") and status().get("shortcutFocused") and (status().get("shortcutSurfaceActive") or status().get("previewSurfaceActive")),
                                     "Ctrl shortcuts lost focus while a window preview was visible")
                                digit = wait(lambda: ipc("shortcutDigit", b), "Visible preview row has no shortcut")
                                print("Preview shortcut setup:", {"beforePreview": before_preview, "scale": scale,
                                      "listActive": status().get("shortcutSurfaceActive"),
                                      "previewActive": status().get("previewSurfaceActive")}, flush=True)
                                keys.stdin.write("tap " + digit + "\n"); keys.stdin.flush()
                                wait(lambda: not status().get("panelMapped") and not status().get("hoverBusy"), "Preview row shortcut did not close hover")
                                wait(lambda: query("activewindow").get("address") == b, "Preview row shortcut selected the wrong tab")
                        print("PASS native digits with Ctrl pressed before and after the row preview opens at scale", scale, flush=True)
                        before = query("activewindow").get("address")
                        ipc("hoverOpen")
                        wait(lambda: status().get("hoverMode"), "Passive hover did not reopen")
                        assert not status().get("shortcutKeyboard"), "Unmodified hover takes the keyboard"
                        with held_keys(keyboard):
                            wait(lambda: status().get("shortcutControl") and status().get("shortcutFocused") and (status().get("shortcutSurfaceActive") or status().get("previewSurfaceActive")), "Ctrl pressed after hover did not take shortcut focus")
                        wait(lambda: not status().get("shortcutControl") and not status().get("shortcutKeyboard"), "Releasing Ctrl did not release shortcut focus")
                        wait(lambda: query("activewindow").get("address") == before, "Hover did not restore application focus")
                        assert status().get("hoverMode") and not status().get("panelOpen"), "Releasing Ctrl expanded or closed hover"
                        ipc("panelClose")
                        wait(lambda: not status().get("panelMapped"), "Hover did not close")
                        assert all((w["workspace"]["name"], w["monitor"], sorted(w.get("grouped", []))) == placements[w["address"]] for w in windows()), "Shortcut moved a window or changed its group"
                        print("PASS hover returns keyboard focus on Ctrl release at scale", scale, flush=True)
                        continue
                    for target in (b, a, c, d, d, b):
                        ipc("panelOpen")
                        wait(lambda: status().get("panelOpen"), "Panel did not open")
                        wait(lambda: ipc("shortcutFilter") == "true", "Search did not get focus")
                        time.sleep(0.2)
                        assert ipc("windowShortcut", target) == "true", "Window key was not delivered"
                        wait(lambda: not status().get("panelOpen") and not status().get("hoverBusy"), "Window action did not finish")
                        assert not status().get("hoverError"), "Window action failed: " + str(status().get("hoverError"))
                        assert query("activewindow").get("address") == target, "Wrong window or tab focused"
                        assert all((w["workspace"]["name"], w["monitor"], sorted(w.get("grouped", []))) == placements[w["address"]] for w in windows()), "Shortcut moved a window or changed its group"
                    print("PASS Ctrl+digit keys select exact windows and group tabs, including named/special workspaces and both monitors at scale", scale, flush=True)
                for item in query("clients"):
                    if item["address"] in initial_windows:
                        assert (item["workspace"]["name"], sorted(item.get("grouped", [])), item.get("monitor")) == initial_windows[item["address"]]
                print("PASS existing windows and groups untouched", flush=True)
                raise SystemExit(0)
            action("focus", a)
            assert query("activewindow").get("address") == a
            print("PASS focus on an inactive named workspace", flush=True)
            evaluate('hl.dispatch(hl.dsp.group.toggle({window = "address:' + a + '"}))')
            evaluate('hl.get_window("address:' + a + '").group:add(hl.get_window("address:' + b + '"))')
            wait(lambda: set(window(a).get("grouped", [])) == {a, b}, "Test group not created")
            action("focus", a)
            hover_focus(b)
            assert query("activewindow").get("address") == b
            assert set(window(a)["grouped"]) == {a, b}
            print("PASS hover click switches hidden tabs without detaching them", flush=True)
            evaluate('if hl.get_active_window() ~= hl.get_window("address:' + b + '") then error("test focus changed") end; '
                     'hl.dispatch(hl.dsp.group.lock_active({action = "on"}))')
            action("move", a, "name:" + destination, "groupLocked")
            assert set(window(a)["grouped"]) == {a, b} and window(a)["workspace"]["name"] == source
            evaluate('if hl.get_active_window() ~= hl.get_window("address:' + b + '") then error("test focus changed") end; '
                     'hl.dispatch(hl.dsp.group.lock_active({action = "off"}))')
            action("move", a, "name:" + destination)
            assert window(a)["workspace"]["name"] == destination
            assert window(b)["workspace"]["name"] == source
            print("PASS locked group refused; unlocked single-tab move preserves sibling", flush=True)
            action("move", a, special_workspace)
            action("focus", a)
            assert query("activewindow").get("address") == a
            assert window(a)["workspace"]["name"] == special_workspace
            action("move", a, "name:" + destination)
            print("PASS move to, focus in and return from a special workspace", flush=True)
            if len(monitors) > 1:
                other = next(m for m in monitors if m["id"] != window(a).get("monitor"))
                # Move only the disposable workspace, then focus its test window.
                evaluate("hl.dispatch(hl.dsp.workspace.move({workspace = " + json.dumps("name:" + destination)
                         + ", monitor = " + json.dumps(other["name"]) + "}))")
                hover_focus(a)
                assert query("activewindow").get("address") == a
                assert window(a)["monitor"] == other["id"], "Focusing an ordinary window moved it to another monitor"
                print("PASS hover click focuses a window on another monitor", flush=True)
                special_monitor = window(d)["monitor"]
                assert special_monitor != other["id"], "Special test needs different source and destination monitors"
                action("focus", d)
                assert window(d)["monitor"] == special_monitor, "Focusing a hidden special workspace moved it"
                action("focus", a)
                assert any(m.get("specialWorkspace", {}).get("name") == special_workspace for m in query("monitors")), "Special workspace must stay visible for the next case"
                hover_focus(d)
                assert window(d)["monitor"] == special_monitor, "Focusing a visible special workspace moved it"
                assert window(d)["workspace"]["name"] == special_workspace
                print("PASS hidden and visible special workspaces retain their monitor on focus", flush=True)
                action("move", b, special_workspace)
                action("focus", d)
                evaluate('hl.dispatch(hl.dsp.group.toggle({window = "address:' + d + '"})); '
                         'hl.get_window("address:' + d + '").group:add(hl.get_window("address:' + b + '"))')
                action("focus", d)
                evaluate('if hl.get_active_window() ~= hl.get_window("address:' + d + '") then error("test focus changed") end; '
                         'hl.dispatch(hl.dsp.group.lock_active({action = "on"}))')
                action("bring", d, other["name"], "groupLocked")
                assert set(window(d)["grouped"]) == {b, d} and window(d)["monitor"] == special_monitor
                action("focus", d)
                evaluate('if hl.get_active_window() ~= hl.get_window("address:' + d + '") then error("test focus changed") end; '
                         'hl.dispatch(hl.dsp.group.lock_active({action = "off"}))')
                ctrl_click(d, other["name"])
                assert window(d)["monitor"] == other["id"] and window(d)["workspace"]["name"] == destination
                assert window(b)["monitor"] == special_monitor and window(b)["workspace"]["name"] == special_workspace
                assert not window(d).get("grouped") or set(window(d)["grouped"]) == {d}
                print("PASS hover Ctrl+Shift+click brings one scratchpad tab; sibling and locked group are preserved", flush=True)

                home = next(m for m in monitors if m["id"] == special_monitor)
                return_workspace = source + "-Return"
                evaluate("hl.dispatch(hl.dsp.focus({monitor = " + json.dumps(home["name"]) + "})); "
                         "hl.dispatch(hl.dsp.focus({workspace = " + json.dumps("name:" + return_workspace) + "}))")
                ctrl_click(c, home["name"], panel=True)
                assert window(c)["monitor"] == home["id"] and window(c)["workspace"]["name"] == return_workspace
                assert window(a)["workspace"]["name"] == destination
                print("PASS full-panel Ctrl+Shift+click brings an ordinary window to the invoking monitor", flush=True)

                ipc("refresh")
                assert ipc("holdBring", d, home["name"]) == "true"
                wait(lambda: status().get("held"), "Bring did not reach its pre-dispatch boundary")
                evaluate("hl.dispatch(hl.dsp.focus({workspace = " + json.dumps("name:" + source + "-Changed") + "}))")
                ipc("releaseBring")
                wait(lambda: status().get("busy") is False, "Stale destination guard did not complete")
                assert status().get("error") == "destinationChanged"
                assert window(d)["monitor"] == other["id"] and window(d)["workspace"]["name"] == destination
                print("PASS changed destination is rejected before moving the window", flush=True)

                action("focus", a)
                evaluate('hl.dispatch(hl.dsp.group.toggle({window = "address:' + a + '"})); '
                         'hl.get_window("address:' + a + '").group:add(hl.get_window("address:' + d + '"))')
                action("bring", d, other["name"])
                assert set(window(a)["grouped"]) == {a, d}, "Bringing a tab already here must not detach it"
                print("PASS Ctrl+Shift+click destination already contains the tab: focus only, group retained", flush=True)
            if args.installed:
                def bar(method, *arguments):
                    return run("omarchy-shell", "sarr.windowpeek", method, *arguments)
                def bar_status():
                    return json.loads(bar("status"))
                try:
                    for monitor in monitors:
                        bar("open", monitor["name"])
                        wait(lambda: any(w["opened"] and w["screen"] == monitor["name"] for w in bar_status()),
                             "Panel did not open on selected monitor")
                        bar("close")
                        wait(lambda: all(not w["opened"] for w in bar_status()), "Panel did not close")
                    action("focus", a)
                    bar("toggle", "")
                    wait(lambda: any(w["opened"] for w in bar_status()), "Shortcut command did not open panel")
                    bar("close")
                    wait(lambda: query("activewindow").get("address") == a, "Closing did not restore previous focus")
                    bar("toggle", "")
                    assert bar("focusWindow", b) == "true"
                    try:
                        wait(lambda: query("activewindow").get("address") == b
                             and all(not w["opened"] and not w["actionBusy"] for w in bar_status()),
                             "Bar focus action did not close panel and focus target")
                    except AssertionError:
                        print("Target focused:", query("activewindow").get("address") == b, flush=True)
                        print("Panel state:", [{k: w[k] for k in ("screen", "opened", "actionBusy", "actionError")} for w in bar_status()], flush=True)
                        raise
                    print("PASS installed panel on both monitors; close restores focus; selection focuses exact target", flush=True)
                finally:
                    bar("close")
            for item in query("clients"):
                if item["address"] in initial_windows:
                    assert (item["workspace"]["name"], sorted(item.get("grouped", [])), item.get("monitor")) == initial_windows[item["address"]]
            print("PASS existing windows and groups untouched", flush=True)
        except Exception:
            print("Fixture status:", status(), flush=True)
            print((config / "runtime.log").read_text()[-6000:], flush=True)
            raise
        finally:
            try:
                ipc("panelClose")
            except subprocess.SubprocessError:
                pass
            for item in windows():
                evaluate('hl.dispatch(hl.dsp.window.close({window = "address:' + item["address"] + '"}))')
            for monitor in monitors:
                if not any(m["name"] == monitor["name"] for m in query("monitors")):
                    continue
                evaluate("hl.dispatch(hl.dsp.focus({monitor = " + json.dumps(monitor["name"]) + "})); "
                         + "hl.dispatch(hl.dsp.focus({workspace = " + json.dumps(selector(monitor["activeWorkspace"])) + "}))")
                special = monitor.get("specialWorkspace", {}).get("name", "")
                value = "{workspace = " + json.dumps(special) + "}" if special else "{}"
                evaluate("hl.get_monitor(" + json.dumps(monitor["name"]) + "):set_special_workspace(" + value + ")")
            if initial_focus and any(w["address"] == initial_focus for w in query("clients")):
                evaluate('local w = hl.get_window("address:' + initial_focus + '"); '
                         'if w.monitor then hl.dispatch(hl.dsp.focus({monitor = w.monitor.name})) end; '
                         'hl.dispatch(hl.dsp.focus({window = "address:' + initial_focus + '"}))')
            shell.terminate()
            shell.wait(timeout=5)
            evaluate("hl.dispatch(hl.dsp.cursor.move({x=" + str(int(initial_cursor["x"]))
                     + ",y=" + str(int(initial_cursor["y"])) + "}))")
