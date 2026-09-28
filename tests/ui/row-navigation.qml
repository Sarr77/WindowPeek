import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property bool advancing: false
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
            if (test.advancing) return;
            test.advancing = true;
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
                    host.setLanguage("en"); panel.searchField.text = ""; panel.searchField.forceActiveFocus(); break;
                case 6:
                    panel.selectedAddress = "0x2";
                    test.key(Qt.Key_Right);
                    test.check(test.focused("0x2", "windowMove"), "typing test starts with Move focused");
                    test.key(Qt.Key_P);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "p",
                        "typing from Move returns to search without losing the first character");
                    test.key(Qt.Key_R); break;
                case 7:
                    test.key(Qt.Key_Right);
                    test.check(window.activeFocusItem.objectName === "windowMove", "filtered query can return to Move");
                    var first = panel.shortcutAddresses[0];
                    test.key(Qt.Key_1, Qt.ControlModifier);
                    test.check(host.focused === first && panel.searchField.text === "pr", "Ctrl+number from Move activates the visible ordinal without editing");
                    host.focused = "";
                    test.key(Qt.Key_Backspace);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "p", "Backspace from Move edits the saved query");
                    test.key(Qt.Key_Right); test.key(Qt.Key_Left); test.key(Qt.Key_Space);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "p " && !host.focused && panel.mode === "windows",
                        "space from the window action types rather than activating a window");
                    panel.searchField.text = ""; break;
                case 8:
                    panel.selectedAddress = "0x2"; panel.searchField.forceActiveFocus();
                    test.key(Qt.Key_Tab);
                    test.check(!panel.searchField.activeFocus, "Tab visits controls");
                    test.key(Qt.Key_P);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "p", "typing after Tab immediately returns to search");
                    panel.searchField.text = "";
                    for (var name of ["settingsButton", "updateSwitch", "authorCredit", "hintsToggle"]) {
                        var control = test.find(panel, name);
                        control.forceActiveFocus(Qt.TabFocusReason);
                        test.key(Qt.Key_P);
                        test.check(panel.searchField.activeFocus && panel.searchField.text === "p" && panel.mode === "windows" && !panel.blockingModalOpen,
                            "typing from " + name + " goes to search");
                        panel.searchField.text = "";
                    }
                    test.find(panel, "updateSwitch").forceActiveFocus(Qt.TabFocusReason);
                    test.key(Qt.Key_2);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "2" && !host.focused,
                        "unmodified digits from controls are search text");
                    panel.searchField.text = "Project"; panel.searchField.selectAll(); panel.searchField.copy(); panel.searchField.text = "";
                    test.find(panel, "authorCredit").forceActiveFocus(Qt.TabFocusReason);
                    test.key(Qt.Key_V, Qt.ControlModifier);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "Project", "paste from footer uses the native search editor");
                    test.find(panel, "settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    test.key(Qt.Key_A, Qt.ControlModifier); test.key(Qt.Key_Backspace);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "", "Ctrl+A and Backspace still edit the query from a control");
                    test.find(panel, "authorCredit").forceActiveFocus(Qt.TabFocusReason); test.key(Qt.Key_Return); break;
                case 9:
                    test.check(panel.blockingModalOpen, "Enter on footer opens its popup");
                    test.key(Qt.Key_P); test.key(Qt.Key_1, Qt.ControlModifier);
                    test.check(panel.searchField.text === "" && !panel.searchField.activeFocus && !host.focused,
                        "popup owns text and blocks background Ctrl+number");
                    test.key(Qt.Key_Escape); break;
                case 10:
                    test.check(!panel.blockingModalOpen && panel.mode === "windows", "Escape closes only the popup");
                    test.key(Qt.Key_P);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "p", "typing resumes immediately after popup dismissal");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
            finally { test.advancing = false; }
        }
    }
}
