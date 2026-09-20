import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property var originalSnapshot: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function key(code, modifiers) { events.keyClick(code, modifiers === undefined ? Qt.ControlModifier : modifiers, 0); }
    function expect(address, message) {
        check(host.focused === address, message);
        check(!host.moved && !host.brought, "window shortcuts do not move windows");
        host.focused = "";
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function row(address) {
        var list = find(panel, "windowList");
        var index = list.rows.findIndex(function(item) { return item.kind === "window" && item.address === address; });
        return list.itemAtIndex(index);
    }
    function controlSample(down) {
        var state = panel.shortcutModifierState;
        state.pending = "fixture";
        state.receive("custom", "windowpeek-shortcut-control,fixture," + (down ? "1" : "0"));
    }
    function checkRightAlignment() {
        var right = -1;
        for (var address of panel.shortcutAddresses) {
            var item = test.row(address);
            var label = test.find(item, "windowShortcutLabel");
            var active = test.find(item, "activeWindowLabel");
            var edge = label.mapToItem(panel, label.width, 0).x;
            if (right < 0) right = edge;
            test.check(label.visible && Math.abs(edge - right) < 0.1, "shortcut numbers align vertically");
            test.check(Math.abs(label.x + label.width - label.parent.width) < 0.1, "number reaches the right edge");
            if (active.visible) test.check(active.x + active.width < label.x, "Active sits left of the number");
        }
    }
    TestEvent { id: events }
    FakeHost { id: host }
    Window {
        id: window
        visible: true; width: 540 * test.scale; height: 1300 * test.scale
        color: Color.popups.background
        Plugin.PanelContent { id: panel; width: 500; height: 1260; scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host }
    }
    Timer {
        interval: 140; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    if (Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        Color.shellValues = ({}); Color.background = "#1b1b26";
                        Color.foreground = "#b7bedb"; Color.accent = host.accent;
                    }
                    test.originalSnapshot = host.snapshot;
                    var snapshot = JSON.parse(JSON.stringify(host.snapshot));
                    snapshot.activeAddress = "0x3";
                    host.snapshot = snapshot;
                    panel.begin(); break;
                case 1:
                    test.key(Qt.Key_1); test.expect("0x3", "first is the displayed active window");
                    test.key(Qt.Key_2); test.expect("0x1", "second is the first row of the next workspace");
                    test.key(Qt.Key_3); test.expect("0x2", "a second tab in the same workspace is a separate position");
                    test.key(Qt.Key_4); test.expect("0x4", "named workspace window is reachable");
                    test.key(Qt.Key_5); test.expect("0x5", "scratchpad window is reachable");
                    test.key(Qt.Key_9); test.check(!host.focused, "missing ordinal does nothing");
                    test.check(panel.searchField.text === "", "Ctrl digits do not edit search");
                    test.key(Qt.Key_Right, Qt.NoModifier);
                    test.key(Qt.Key_2); test.expect("0x1", "shortcut works with Move focused");
                    panel.searchField.forceActiveFocus(); panel.searchField.text = "Reading"; break;
                case 2:
                    test.key(Qt.Key_1); test.expect("0x5", "filtered list defines ordinal one");
                    test.key(Qt.Key_2); test.check(!host.focused, "filtered-out window is not activated");
                    panel.searchField.text = ""; host.includeSpecial = false; break;
                case 3:
                    test.key(Qt.Key_5); test.check(!host.focused, "hidden special workspace has no shortcut");
                    host.actionBusy = true; test.key(Qt.Key_1); test.check(!host.focused, "busy blocks shortcut");
                    host.actionBusy = false; host.moveMenuOpen = true; test.key(Qt.Key_1);
                    test.check(!host.focused, "move menu blocks shortcut"); host.moveMenuOpen = false;
                    panel.expanded = false; test.key(Qt.Key_1); test.expect("0x3", "hover uses the same numbered window action");
                    test.check(!panel.expanded, "a shortcut does not expand hover");
                    panel.expanded = true; panel.mode = "settings"; test.key(Qt.Key_1);
                    test.check(!host.focused, "settings block shortcut"); panel.back();
                    test.key(Qt.Key_1, Qt.ControlModifier | Qt.ShiftModifier);
                    test.key(Qt.Key_1, Qt.ControlModifier | Qt.AltModifier);
                    test.check(!host.focused, "other modifier combinations are left alone");
                    var repeated = {key: Qt.Key_1, modifiers: Qt.ControlModifier, isAutoRepeat: true, accepted: false};
                    panel.handleWindowShortcut(repeated); test.check(repeated.accepted && !host.focused, "repeat is consumed without a second action");
                    var many = {clients: [], workspaces: [], monitors: host.snapshot.monitors, activeAddress: "0x1"};
                    for (var i = 1; i <= 11; i++) {
                        var workspace = {id: i * 3, name: String(i * 3), monitorID: 7};
                        many.workspaces.push(workspace);
                        many.clients.push({address: "0x" + i.toString(16), title: "Window " + i, workspace: workspace});
                    }
                    host.snapshot = many; panel.begin(); break;
                case 4:
                    for (var n = 1; n <= 9; n++) { test.key(Qt.Key_0 + n); test.expect("0x" + n.toString(16), "digit " + n + " follows window position"); }
                    test.key(Qt.Key_0); test.expect("0xa", "zero chooses the tenth window");
                    test.key(Qt.Key_0, Qt.ControlModifier | Qt.KeypadModifier); test.expect("0xa", "numeric keypad works");
                    events.keyRelease(Qt.Key_Control, Qt.NoModifier, 0);
                    test.check(!test.find(test.row("0x1"), "windowShortcutLabel").visible, "hints are hidden without Ctrl");
                    events.keyPress(Qt.Key_Control, Qt.NoModifier, 0);
                    test.check(test.find(test.row("0x1"), "windowShortcutLabel").visible, "Ctrl reveals shortcut labels");
                    test.check(test.find(test.row("0xa"), "windowShortcutLabel").text === "0", "tenth visible row is labelled zero");
                    test.check(!test.find(test.row("0xb"), "windowShortcutLabel").visible, "no duplicate shortcut for the eleventh row");
                    panel.height = 260;
                    var list = test.find(panel, "windowList");
                    list.contentY = test.row("0x7").y + 10;
                    break;
                case 5:
                    test.check(panel.shortcutAddresses[0] === "0x7", "first intersecting row starts at one after scrolling");
                    test.check(test.find(test.row("0x7"), "windowShortcutLabel").visible
                        && test.find(test.row("0x7"), "windowShortcutLabel").text === "1", "visible label is renumbered after scrolling");
                    test.check(!test.find(test.row("0x1"), "windowShortcutLabel").visible, "offscreen row has no shortcut hint");
                    test.key(Qt.Key_1); test.expect("0x7", "Ctrl+1 activates the same row as the visible one label");
                    test.key(Qt.Key_0); test.check(!host.focused, "zero cannot choose an offscreen tenth row");
                    test.find(panel, "windowList").contentY = test.row("0x9").y;
                    break;
                case 6:
                    test.key(Qt.Key_1); test.expect("0x9", "renumbering follows the new viewport");
                    events.keyRelease(Qt.Key_Control, Qt.NoModifier, 0);
                    test.check(!test.find(test.row("0x9"), "windowShortcutLabel").visible, "releasing Ctrl hides hints after scrolling");
                    panel.dismiss(); test.key(Qt.Key_1); test.check(!host.focused, "closed panel blocks shortcut");
                    test.check(!panel.shortcutModifierState.active && !panel.controlHeld, "closing stops Ctrl observation");
                    test.controlSample(true); test.check(!panel.controlHeld, "late sample after closing is ignored");
                    host.snapshot = test.originalSnapshot; host.includeSpecial = true;
                    panel.height = 600; window.height = 640 * test.scale;
                    panel.expanded = false; panel.begin(false); test.controlSample(true); break;
                case 7:
                    test.check(panel.controlHeld && test.find(test.row("0x1"), "windowShortcutLabel").visible,
                        "Ctrl already held at hover opening shows numbers without a key press");
                    panel.forceActiveFocus(); test.key(Qt.Key_2); test.expect("0x2", "number activates a hover group tab");
                    panel.shortcutModifierState.pending = "stale";
                    events.keyRelease(Qt.Key_Control, Qt.NoModifier, 0);
                    panel.shortcutModifierState.receive("custom", "windowpeek-shortcut-control,stale,1");
                    test.check(!panel.controlHeld, "old sample cannot undo a newer key release");
                    panel.expanded = true; panel.begin(); test.controlSample(true);
                    test.check(panel.controlHeld, "Ctrl already held also works when opening search");
                    panel.showSettings(); test.find(panel, "settingsListSection").expanded = true; break;
                case 8:
                    var toggle = test.find(panel, "shortcutNumbersRightToggle");
                    test.check(!toggle.checked && !host.shortcutNumbersRight, "inline numbering is the default");
                    panel.ensureVisible(toggle);
                    events.mouseClick(toggle, 20, 20, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 9:
                    test.check(host.shortcutNumbersRight, "settings saves right-aligned numbering");
                    host.rejectSave = true; test.find(panel, "shortcutNumbersRightToggle").activate();
                    test.check(host.shortcutNumbersRight, "failed save preserves the previous alignment");
                    host.rejectSave = false; panel.back(); test.controlSample(true); break;
                case 10:
                    test.checkRightAlignment();
                    host.language = "ar"; break;
                case 11:
                    test.checkRightAlignment();
                    host.language = "en"; host.persistSettings({shortcutNumbersRight:false}); break;
                case 12:
                    var item = test.row("0x1");
                    var label = test.find(item, "windowShortcutLabel");
                    var app = test.find(item, "windowAppLabel");
                    test.check(label.x > app.x + app.width && label.x - app.x - app.width < 10,
                        "disabling right alignment restores the number after the app/tab label");
                    if (!Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                    }
                    host.persistSettings({shortcutNumbersRight:true}); break;
                case 13:
                    console.info("WINDOWPEEK_TEST_PASS"); stop();
                    window.contentItem.grabToImage(function(result) {
                        result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); Qt.quit();
                    });
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
