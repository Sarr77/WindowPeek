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
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function named(name) { return find(panel, name); }
    function focusName() {
        var item = window.activeFocusItem;
        if (!item) return "none";
        return item.objectName + (item.parent && item.parent.window ? ":" + item.parent.window.address : "");
    }
    function key(code, mods) { events.keyClick(code, mods || Qt.NoModifier, 0); }
    function walk(order, backwards) {
        for (var expected of order) {
            key(backwards ? Qt.Key_Backtab : Qt.Key_Tab, backwards ? Qt.ShiftModifier : Qt.NoModifier);
            check(focusName() === expected, "Tab expected " + expected + ", got " + focusName());
        }
    }
    function arrows(code, order) {
        var address = panel.selectedAddress;
        for (var expected of order) {
            key(code);
            check(focusName() === expected, "Arrow expected " + expected + ", got " + focusName());
            check(panel.selectedAddress === address, "outer arrows preserve the remembered window");
        }
    }
    TestEvent { id: events }
    FakeHost { id: host; property var runtime: ({updates:{manualAvailable:false}}) }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: 660 * test.scale
        Plugin.PanelContent {
            id: panel; x: 20 * test.scale; y: 20 * test.scale; width: 500; height: 260
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
        Item { objectName: "outsidePanel"; activeFocusOnTab: true }
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
                    test.check(panel.searchField.activeFocus, "opening prepares immediate search");
                    test.check(!test.named("windowFocus").emphasized, "search focus does not outline a window row");
                    test.walk(["windowFocus:0x1"], false);
                    test.check(window.activeFocusItem.emphasized, "first Tab enters and outlines the list");
                    test.walk(["hintsToggle"], false);
                    test.check(!test.named("windowFocus").emphasized, "second Tab leaves the list and removes its outline");
                    test.walk(["windowFocus:0x1", "windowSearch"], true);
                    test.check(!test.named("windowFocus").emphasized, "returning to search removes the row outline");
                    test.named("settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    var order = ["windowSearch", "windowFocus:0x1", "hintsToggle", "updateSwitch", "authorCredit", "settingsButton"];
                    test.walk(order, false);
                    test.walk(order.slice(0, -1).reverse().concat(["settingsButton"]), true);
                    test.check(!host.focused && !host.moved && panel.mode === "windows", "Tab only navigates");
                    test.walk(["windowSearch", "windowFocus:0x1"], false);
                    test.key(Qt.Key_Right);
                    for (var i = 0; i < 4; i++) test.key(Qt.Key_Down);
                    test.check(test.focusName() === "windowMove:0x5" && panel.contentY > 0,
                        "arrows navigate the list and reveal the selected action");
                    var previousAction = window.activeFocusItem;
                    test.walk(["hintsToggle"], false);
                    test.check(!previousAction.emphasized && !test.find(previousAction.parent, "windowFocus").emphasized,
                        "leaving Move clears both keyboard outlines while retaining the selection");
                    test.check(panel.selectedAddress === "0x5", "leaving the list retains the selected address");
                    test.arrows(Qt.Key_Right, ["updateSwitch", "authorCredit", "settingsButton", "hintsToggle"]);
                    test.arrows(Qt.Key_Up, ["settingsButton", "authorCredit", "updateSwitch", "hintsToggle"]);
                    test.walk(["windowMove:0x5"], true);
                    test.check(window.activeFocusItem.emphasized, "returning restores Move's keyboard outline");
                    test.walk(["hintsToggle"], false);
                    test.walk(["windowMove:0x5", "windowSearch"], true);
                    test.walk(["windowMove:0x5", "hintsToggle"], false);
                    test.walk(["windowMove:0x5"], true);
                    test.key(Qt.Key_Left);
                    previousAction = window.activeFocusItem;
                    test.walk(["hintsToggle"], false);
                    test.check(!previousAction.emphasized, "leaving the window action clears its keyboard outline");
                    test.walk(["windowFocus:0x5"], true);
                    test.check(window.activeFocusItem.emphasized, "returning restores the keyboard outline on the remembered action");
                    panel.panelPinned = true; break;
                case 2:
                    test.named("authorCredit").forceActiveFocus(Qt.TabFocusReason);
                    test.walk(["closePinnedPanel", "pinPanelButton", "settingsButton", "windowSearch"], false);
                    test.check(test.named("pinPanelButton").checked, "Tab does not toggle pinned state");
                    test.walk(["settingsButton", "pinPanelButton", "closePinnedPanel", "authorCredit"], true);
                    test.arrows(Qt.Key_Down, ["closePinnedPanel", "pinPanelButton", "settingsButton", "hintsToggle"]);
                    panel.panelPinned = false;
                    panel.searchField.text = "Reading"; break;
                case 3:
                    test.named("settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    test.walk(["windowSearch", "windowFocus:0x5", "hintsToggle", "updateSwitch", "authorCredit", "settingsButton"], false);
                    panel.searchField.text = "no matching window"; break;
                case 4:
                    test.named("settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    test.walk(["windowSearch", "hintsToggle", "updateSwitch", "authorCredit", "settingsButton"], false);
                    panel.searchField.text = ""; host.setLanguage("ar"); break;
                case 5:
                    test.named("settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    test.walk(["windowSearch", "windowFocus:0x1"], false);
                    test.key(Qt.Key_Left); test.key(Qt.Key_Down);
                    test.check(test.focusName() === "windowMove:0x2", "RTL arrows still operate within the list");
                    test.walk(["hintsToggle"], false);
                    test.walk(["windowMove:0x2", "windowSearch", "settingsButton", "authorCredit"], true);
                    test.arrows(Qt.Key_Left, ["settingsButton", "hintsToggle", "updateSwitch", "authorCredit"]);
                    test.arrows(Qt.Key_Right, ["updateSwitch", "hintsToggle", "settingsButton", "authorCredit"]);
                    test.key(Qt.Key_Return); break;
                case 6:
                    test.check(panel.blockingModalOpen, "support modal opens");
                    test.walk(["starWindowPeekGitHub", "projectSupportIssues", "starWindowPeekCatalog"], false);
                    test.walk(["projectSupportIssues", "starWindowPeekGitHub", "starWindowPeekCatalog"], true);
                    test.walk(["starWindowPeekGitHub", "projectSupportIssues"], false); break;
                case 7:
                    var scroll = test.named("projectSupportScroll");
                    var item = test.named("projectSupportIssues");
                    var top = item.mapToItem(scroll.contentItem, 0, 0).y;
                    test.check(top >= scroll.contentY - 1 && top + item.height <= scroll.contentY + scroll.height + 1,
                        "Tab reveals focused popup actions when space is limited");
                    test.key(Qt.Key_P); test.key(Qt.Key_1, Qt.ControlModifier);
                    test.check(panel.searchField.text === "" && !host.focused, "modal blocks typing and window shortcuts in the background");
                    test.key(Qt.Key_Escape); break;
                case 8:
                    test.check(!panel.blockingModalOpen && test.focusName() === "authorCredit", "Escape restores the popup opener");
                    test.named("updateSwitch").forceActiveFocus(Qt.TabFocusReason); test.key(Qt.Key_Return); break;
                case 9:
                    test.check(panel.blockingModalOpen, "update confirmation opens");
                    test.walk(["confirmUpdateOff", "cancelUpdateOff", "confirmUpdateOff", "cancelUpdateOff"], false);
                    test.walk(["confirmUpdateOff", "cancelUpdateOff"], true);
                    test.check(test.named("cancelUpdateOff").keyboardFocusVisible, "Tab focus cue is visible in the modal");
                    test.key(Qt.Key_Escape); break;
                case 10:
                    test.check(!panel.blockingModalOpen && test.focusName() === "updateSwitch", "confirmation restores its opener");
                    host.setLanguage("en"); test.key(Qt.Key_P);
                    test.check(panel.searchField.activeFocus && panel.searchField.text === "p", "typing immediately resumes after Tab and popup dismissal");
                    panel.searchField.text = "";
                    host.runtime = {updates:{manualAvailable:true}};
                    panel.closingFocusNotice = {shown:true, attention:false, label:"Review", text:"Typing protection", canDisable:true, stopLabel:"Turn off"};
                    break;
                case 11:
                    test.named("authorCredit").forceActiveFocus(Qt.TabFocusReason);
                    test.walk(["availableUpdateButton", "settingsButton", "focusRecoveryNotice", "turnOffFocusProtection", "windowSearch"], false);
                    test.walk(["turnOffFocusProtection", "focusRecoveryNotice", "settingsButton", "availableUpdateButton", "authorCredit"], true);
                    test.arrows(Qt.Key_Down, ["availableUpdateButton", "settingsButton", "focusRecoveryNotice", "turnOffFocusProtection", "hintsToggle", "updateSwitch", "authorCredit"]);
                    test.named("updateSwitch").enabled = false;
                    test.walk(["hintsToggle"], true);
                    test.arrows(Qt.Key_Down, ["authorCredit"]);
                    test.arrows(Qt.Key_Up, ["hintsToggle"]);
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
            finally { test.advancing = false; }
        }
    }
}
