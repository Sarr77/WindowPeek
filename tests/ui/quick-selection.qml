import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property double started: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function key(code, modifiers) { events.keyClick(code, modifiers || Qt.NoModifier, 0); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function expectDigit(code, modifiers, address) {
        host.focused = ""; key(code, modifiers);
        check(host.focused === address, "quick digit selects " + address + ", got " + host.focused);
        check(!host.brought && !host.moved && !panel.searchField.text, "digits select without moving or editing");
    }
    TestEvent { id: events }
    FakeHost { id: host }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: 1700 * test.scale
        Plugin.PanelContent {
            id: panel; x: 20 * test.scale; y: 20 * test.scale; width: 500; height: 1660
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    var snapshot = JSON.parse(JSON.stringify(host.snapshot));
                    snapshot.clients = []; snapshot.workspaces = [];
                    for (var i = 1; i <= 12; i++) {
                        var workspace = {id: i, name: String(i), monitor: "DP-1"};
                        snapshot.workspaces.push(workspace);
                        snapshot.clients.push({address: "0x" + i.toString(16), title: "Window " + i, workspace: workspace});
                    }
                    host.snapshot = snapshot; panel.begin(); break;
                case 1:
                    test.check(!panel.quickSelection, "ordinary mouse opening does not enable quick digits");
                    panel.startQuickSelection();
                    test.check(panel.quickSelection && !panel.controlHeld, "quick digits do not fake physical Ctrl");
                    var keypad = [Qt.Key_Insert, Qt.Key_End, Qt.Key_Down, Qt.Key_PageDown,
                        Qt.Key_Left, Qt.Key_Clear, Qt.Key_Right, Qt.Key_Home, Qt.Key_Up, Qt.Key_PageUp];
                    for (var digit = 0; digit <= 9; digit++) {
                        var address = "0x" + (digit || 10).toString(16);
                        test.expectDigit(Qt.Key_0 + digit, Qt.NoModifier, address);
                        test.expectDigit(Qt.Key_0 + digit, Qt.KeypadModifier, address);
                        test.expectDigit(keypad[digit], Qt.KeypadModifier, address);
                    }
                    panel.height = 300; window.height = 340 * test.scale; break;
                case 2:
                    var list = test.find(panel, "windowList");
                    test.key(Qt.Key_PageDown);
                    test.check(panel.contentY > 0 && panel.quickSelection, "Page Down scrolls without cancelling quick selection");
                    test.expectDigit(Qt.Key_1, Qt.NoModifier, panel.shortcutAddresses[0]);
                    test.key(Qt.Key_End);
                    test.check(panel.selectedAddress === "0xc" && Math.abs(list.contentY-list.contentHeight+list.height)<1,
                        "End reaches the last window and bottom of list");
                    test.key(Qt.Key_Home);
                    test.check(panel.contentY === 0 && panel.selectedAddress === "0x1", "Home returns to first window");
                    test.key(Qt.Key_PageDown); test.key(Qt.Key_PageUp);
                    test.check(panel.contentY === 0, "Page Up returns to beginning");
                    test.key(Qt.Key_Right); test.key(Qt.Key_End);
                    test.check(window.activeFocusItem.objectName === "windowMove" && panel.selectedAddress === "0xc",
                        "paging from a row retains the Move action column");
                    test.key(Qt.Key_Home); panel.searchField.forceActiveFocus();
                    test.key(Qt.Key_W);
                    test.check(!panel.quickSelection && panel.searchField.text === "w", "typing starts search immediately");
                    host.focused = ""; test.key(Qt.Key_2);
                    test.check(!host.focused && panel.searchField.text === "w2", "numbers become normal search text");
                    test.key(Qt.Key_Home);
                    test.check(panel.searchField.cursorPosition === 0, "Home edits a nonempty search query");
                    panel.searchField.text = ""; panel.startQuickSelection();
                    test.started = Date.now(); break;
                case 3:
                    if (Date.now() - test.started < 4700) {
                        test.check(panel.quickSelection, "numbers remain available before five seconds"); test.step--; break;
                    }
                    break;
                case 4:
                    if (Date.now() - test.started < 5150) { test.step--; break; }
                    test.check(!panel.quickSelection, "quick selection expires after five seconds");
                    test.expectDigit(Qt.Key_1, Qt.ControlModifier, panel.shortcutAddresses[0]);
                    host.focused = ""; test.key(Qt.Key_3);
                    test.check(!host.focused && panel.searchField.text === "3", "bare digits type after timeout");
                    panel.searchField.text = ""; panel.startQuickSelection(); panel.showSettings();
                    test.check(!panel.quickSelection, "settings cancels quick selection");
                    panel.back(); panel.startQuickSelection(); panel.demote();
                    test.check(!panel.quickSelection, "collapse cancels quick selection");
                    panel.startQuickSelection(); panel.dismiss();
                    test.check(!panel.quickSelection, "dismiss cancels quick selection");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
