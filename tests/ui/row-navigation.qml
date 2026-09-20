import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function key(code, modifiers) { events.keyClick(code, modifiers || Qt.NoModifier, 0); }
    function focused(address, action) {
        var item = window.activeFocusItem;
        return item && item.objectName === action && item.parent.window.address === address;
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    TestEvent { id: events }
    FakeHost { id: host }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: 300 * test.scale
        color: Color.popups.background
        Plugin.PanelContent {
            id: panel; x: 20 * test.scale; y: 20 * test.scale; width: 500; height: 260
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
    }
    Timer {
        interval: 140; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.begin(); break;
                case 1:
                    test.key(Qt.Key_Down); test.key(Qt.Key_Right);
                    test.check(test.focused("0x2", "windowMove"), "Right enters Move for the arrow-selected window");
                    test.check(!test.find(window.activeFocusItem.parent, "windowFocus").selected,
                        "keyboard selection emphasizes only the current action");
                    test.key(Qt.Key_Down);
                    test.check(test.focused("0x3", "windowMove"), "Down keeps the Move column across workspaces");
                    test.key(Qt.Key_Down); test.key(Qt.Key_Down);
                    test.check(test.focused("0x5", "windowMove") && panel.contentY > 0, "navigation scrolls a hidden row into view");
                    test.key(Qt.Key_Down);
                    test.check(test.focused("0x5", "windowMove"), "last-row boundary does not wrap or activate");
                    test.key(Qt.Key_Left);
                    test.check(test.focused("0x5", "windowFocus"), "Left returns to the same window action");
                    test.key(Qt.Key_Up);
                    test.check(test.focused("0x4", "windowFocus"), "Up keeps the window column");
                    test.key(Qt.Key_Right); test.key(Qt.Key_Return); break;
                case 2:
                    test.check(panel.mode === "move" && panel.moveAddress === "0x4" && !host.moved && !host.focused,
                        "Enter on Move opens the destination form without activating the window");
                    panel.back(); break;
                case 3:
                    for (var code of [Qt.Key_P, Qt.Key_R, Qt.Key_O, Qt.Key_J]) test.key(code);
                    panel.searchField.cursorPosition = 1;
                    test.key(Qt.Key_Right);
                    test.check(panel.searchField.activeFocus && panel.searchField.cursorPosition === 2, "Right inside a query edits the cursor");
                    panel.searchField.selectAll(); test.key(Qt.Key_Right);
                    test.check(panel.searchField.activeFocus && !panel.searchField.selectedText, "Right collapses a text selection before navigating");
                    test.key(Qt.Key_Right);
                    test.check(window.activeFocusItem.objectName === "windowMove", "Right at the query edge enters Move");
                    test.key(Qt.Key_Left); test.key(Qt.Key_Return);
                    test.check(host.focused === panel.selectedAddress, "Enter after Left activates the selected window");
                    host.focused = ""; panel.searchField.forceActiveFocus(); panel.searchField.text = "no-result";
                    test.key(Qt.Key_Right);
                    test.check(panel.searchField.activeFocus && !host.focused && !host.moved, "empty results have no Move target");
                    panel.searchField.text = ""; panel.selectedAddress = "0x1"; host.setLanguage("ar"); break;
                case 4:
                    test.key(Qt.Key_Left);
                    test.check(test.focused("0x1", "windowMove"), "RTL Left follows the visible Move column");
                    var move = window.activeFocusItem;
                    var main = test.find(move.parent, "windowFocus");
                    test.check(move.x + move.width <= main.x, "RTL columns are visually separate, with Move on the left");
                    test.key(Qt.Key_Right);
                    test.check(test.focused("0x1", "windowFocus"), "RTL Right returns to the window");
                    test.key(Qt.Key_Left); host.actionBusy = true; test.key(Qt.Key_Return);
                    test.check(panel.mode === "windows" && !host.moved && !host.focused, "busy Move cannot trigger an action");
                    host.actionBusy = false;
                    var next = JSON.parse(JSON.stringify(host.snapshot));
                    next.clients = next.clients.filter(function(row) { return row.address !== "0x1"; });
                    host.snapshot = next; break;
                case 5:
                    test.key(Qt.Key_Return);
                    test.check(panel.mode === "windows" && !host.moved && !host.focused,
                        "removing the focused window cannot act on its replacement");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
