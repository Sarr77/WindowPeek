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
    function row(address) {
        var list=find(panel,"windowList");
        for (var i=0;i<list.rows.length;i++) {
            var item=list.itemAtIndex(i);
            if (item && item.model.kind==="window" && item.model.address===address) return item.item;
        }
        return null;
    }
    TestEvent { id: events }
    QtObject {
        id: previewProbe
        property Item anchorItem: null
        property string address: ""
        property bool visible: false
        property bool containsPointer: false
        property bool menuRetained: false
        property bool immediate: false
        function showFor(item, value, bounds, now) {
            anchorItem=item; address=value; visible=true; immediate=now === true;
        }
        function hideFor(item) { if (anchorItem === item) dismiss(); }
        function dismiss() { anchorItem=null; address=""; visible=false; }
    }
    FakeHost { id: host; windowPreview: previewProbe }
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
                    test.check(panel.selectedAddress === "0x1" && !test.find(panel,"windowFocus").emphasized
                        && !previewProbe.visible, "opening remembers the active window without outlining or previewing it");
                    test.key(Qt.Key_Up);
                    test.check(panel.selectedAddress === "0x5" && panel.keyboardSelectionVisible
                        && previewProbe.address === "0x5" && previewProbe.immediate,
                        "first Up wraps to the last window and requests its preview immediately");
                    test.key(Qt.Key_Down);
                    test.check(panel.selectedAddress === "0x1", "Down wraps from last to first");
                    test.key(Qt.Key_Down);
                    test.check(panel.selectedAddress === "0x2" && test.find(test.row("0x2"),"windowFocus").emphasized,
                        "first Down from the active window outlines the second window");
                    test.key(Qt.Key_Right);
                    test.check(test.focused("0x2", "windowMove"), "Right enters Move for the arrow-selected window");
                    test.check(!test.find(window.activeFocusItem.parent, "windowFocus").selected,
                        "keyboard selection emphasizes only the current action");
                    test.key(Qt.Key_Down);
                    test.check(test.focused("0x3", "windowMove"), "Down keeps the Move column across workspaces");
                    test.key(Qt.Key_Down); test.key(Qt.Key_Down);
                    test.check(test.focused("0x5", "windowMove") && panel.contentY > 0, "navigation scrolls a hidden row into view");
                    test.key(Qt.Key_Down);
                    test.check(test.focused("0x1", "windowMove"), "last-row Down wraps to the first window, keeping Move");
                    test.key(Qt.Key_Up);
                    test.check(test.focused("0x5", "windowMove"), "first-row Up wraps back to the last window");
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
                    test.check(panel.selectedAddress === "0x1" && test.find(panel,"windowFocus").selected
                        && previewProbe.address === "0x1" && previewProbe.immediate,
                        "live search selects, outlines and previews its first result");
                    test.key(Qt.Key_Up);
                    test.check(panel.selectedAddress === "0x2", "Up wraps within filtered windows");
                    test.key(Qt.Key_Return);
                    test.check(host.focused === "0x2", "Enter activates the arrow-selected filtered result");
                    host.focused = "";
                    test.key(Qt.Key_Down);
                    test.check(panel.selectedAddress === "0x1", "Down wraps back within filtered windows");
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
                    test.check(panel.searchField.activeFocus && !host.focused && !host.moved
                        && !panel.keyboardSelectionVisible && !previewProbe.visible,
                        "empty results have no Move target, outline or preview");
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
                    panel.searchField.text = "";
                    window.height = 700 * test.scale;
                    panel.height = 600;
                    panel.searchField.forceActiveFocus();
                    test.find(panel, "windowList").positionViewAtBeginning();
                    panel.selectedAddress = "0x1";
                    test.key(Qt.Key_Down);
                    test.check(panel.selectedAddress === "0x2" && previewProbe.immediate,
                        "keyboard selection owns the second window before pointer movement");
                    test.find(panel, "windowList").focusAction("0x2", false);
                    var hovered = test.find(test.row("0x3"), "windowFocus");
                    events.mouseMove(hovered, hovered.width / 2, hovered.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    break;
                case 11:
                    test.check(panel.selectedAddress === "0x3" && !panel.keyboardSelectionVisible
                        && panel.pointerSelectionActive && !test.find(test.row("0x2"), "windowFocus").emphasized
                        && previewProbe.address === "0x3" && !previewProbe.immediate,
                        "moving the pointer transfers highlight and normal preview without leaving the old focus outline");
                    test.key(Qt.Key_Down);
                    test.check(panel.selectedAddress === "0x4" && !panel.pointerSelectionActive,
                        "the next arrow continues from the pointer-selected window");
                    break;
                case 12:
                    test.check(panel.keyboardSelectionVisible && previewProbe.address === "0x4" && previewProbe.immediate,
                        "keyboard outline and instant preview return after pointer selection");
                    test.check(!test.find(test.row("0x3"), "windowFocus").hovered
                        && test.find(test.row("0x4"), "windowFocus").emphasized,
                        "the keyboard outline is the only highlighted expanded row");
                    panel.searchField.forceActiveFocus();
                    var movePointer = test.find(test.row("0x2"), "windowMovePointer");
                    events.mouseMove(movePointer, movePointer.width / 2, movePointer.height / 2,
                        0, Qt.NoButton, Qt.NoModifier);
                    break;
                case 13:
                    test.check(panel.searchField.activeFocus && panel.selectedAddress === "0x2"
                        && panel.pointerSelectionActive && !panel.keyboardSelectionVisible,
                        "moving over Move transfers selection without taking typing focus from Search");
                    test.key(Qt.Key_Up);
                    test.check(panel.selectedAddress === "0x5" && panel.keyboardSelectionVisible,
                        "Search arrow continues from the pointer-selected Move row");
                    test.check(!test.find(test.row("0x2"), "windowMove").hovered,
                        "the stationary pointer does not highlight Move during keyboard navigation");
                    panel.height = 260;
                    test.find(panel, "windowList").positionViewAtBeginning();
                    var mainPointer = test.find(test.row("0x2"), "windowFocusPointer");
                    events.mouseMove(mainPointer, mainPointer.width / 2, mainPointer.height / 2,
                        0, Qt.NoButton, Qt.NoModifier);
                    break;
                case 14:
                    test.check(panel.selectedAddress === "0x2" && panel.pointerSelectionActive,
                        "real pointer movement takes over before the expanded list scrolls");
                    for (var expected of ["0x3", "0x4", "0x5", "0x2", "0x3", "0x4", "0x5"]) {
                        test.key(Qt.Key_Down);
                        test.check(panel.selectedAddress === expected && panel.keyboardSelectionVisible,
                            "expanded list scrolling beneath a stationary pointer keeps keyboard selection on " + expected);
                    }
                    test.check(panel.contentY > 0, "expanded list scrolls during repeated Down keys");
                    test.check(!test.find(panel, "windowList").rowHovered,
                        "expanded scrolling under the stationary pointer does not restore hover styling");
                    var again = test.find(test.row("0x4"), "windowFocusPointer");
                    events.mouseMove(again, again.width / 2, again.height / 2,
                        0, Qt.NoButton, Qt.NoModifier);
                    break;
                case 15:
                    test.check(panel.selectedAddress === "0x4" && panel.pointerSelectionActive
                        && test.find(test.row("0x4"), "windowFocus").hovered,
                        "real mouse movement restores hover styling");
                    test.key(Qt.Key_Down);
                    test.check(panel.selectedAddress === "0x5"
                        && !test.find(test.row("0x4"), "windowFocus").hovered
                        && test.find(test.row("0x5"), "windowFocus").emphasized,
                        "keyboard navigation removes the previous mouse hover again");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
            finally { test.advancing = false; }
        }
    }
}
