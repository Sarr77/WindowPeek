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
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) {
            var match = find(item.children[i], name);
            if (match) return match;
        }
        return null;
    }
    function click(item, modifiers) {
        check(!!item, "click target exists");
        events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, modifiers, 0);
    }
    TestEvent { id: events }
    FakeHost { id: host }
    Window {
        id: window; visible: true; width: 1020 * test.scale; height: 680 * test.scale
        color: Color.popups.background
        Rectangle { anchors.fill: parent; color: Color.popups.background }
        Item {
            width: 1020; height: 680; scale: test.scale; transformOrigin: Item.TopLeft
            Plugin.PanelContent { id: panel; x: 10; y: 10; width: 530; height: 650; hostWidget: host }
            Plugin.TooltipContent {
                id: preview; x: 560; y: 10; width: 440; height: implicitHeight; hostWidget: host
                onFocusRequested: function(address) { host.focusWindow(address); }
                onBringRequested: function(address) { host.bringWindow(address); }
                onMoveRequested: function(address) { host.chooseDestination(address); }
            }
        }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.begin(false); break;
                case 1:
                    test.click(test.find(panel, "windowFocusPointer"), Qt.NoModifier);
                    test.check(host.focused === "0x1" && !host.brought, "plain panel click only focuses");
                    host.focused = "";
                    test.click(test.find(panel, "windowFocusPointer"), Qt.ControlModifier | Qt.ShiftModifier);
                    test.check(host.brought === "0x1" && !host.focused, "Ctrl+Shift+click in panel only brings");
                    test.check(test.find(panel, "windowFocusHint").text.indexOf(host.words.bringHint) >= 0, "row hint describes Ctrl+Shift+click");
                    host.brought = "";
                    test.click(test.find(preview, "windowFocusPointer"), Qt.NoModifier);
                    test.check(host.focused === "0x1" && !host.brought, "plain preview click only focuses");
                    host.focused = "";
                    test.click(test.find(preview, "windowFocusPointer"), Qt.ControlModifier | Qt.ShiftModifier);
                    test.check(host.brought === "0x1" && !host.focused, "Ctrl+Shift+click in preview only brings");
                    host.brought = ""; host.actionBusy = true; break;
                case 2:
                    test.click(test.find(panel, "windowFocusPointer"), Qt.ControlModifier | Qt.ShiftModifier);
                    test.click(test.find(preview, "windowFocusPointer"), Qt.ControlModifier | Qt.ShiftModifier);
                    test.check(!host.brought, "busy controls do not start another bring");
                    host.actionBusy = false; host.setLanguage("pl"); break;
                case 3:
                    test.click(test.find(panel, "windowFocusPointer"), Qt.ControlModifier);
                    test.check(panel.mode === "windows" && host.destinationRequested === "0x1" && !host.brought && !host.moved,
                        "Ctrl+click opens the chooser without moving anything");
                    test.click(test.find(panel, "windowMovePointer"), Qt.NoModifier);
                    break;
                case 4:
                    test.check(test.find(panel, "destinationPicker").popupOpen, "destination picker opens after the click");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                    break;
                case 5:
                    test.check(panel.mode === "move" && !test.find(panel, "destinationPicker").popupOpen, "Escape closes only the picker");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 6:
                    test.check(panel.mode === "windows", "Escape returns to the window list after cancelling the picker");
                    test.click(test.find(preview, "windowFocusPointer"), Qt.ControlModifier);
                    test.check(host.destinationRequested === "0x1" && !host.brought && !host.moved,
                        "Ctrl+click in overview requests the same chooser");
                    host.destinationRequested = "";
                    panel.expanded = false;
                    test.click(test.find(panel, "windowFocusPointer"), Qt.ControlModifier);
                    test.check(host.destinationRequested === "0x1", "collapsed unified panel requests expansion into the chooser");
                    host.destinationRequested = ""; host.actionBusy = true;
                    test.click(test.find(panel, "windowFocusPointer"), Qt.ControlModifier);
                    test.click(test.find(preview, "windowFocusPointer"), Qt.ControlModifier);
                    test.check(!host.destinationRequested, "busy lists do not open a move chooser");
                    host.actionBusy = false; panel.expanded = true;
                    break;
                case 7:
                    var target = test.find(panel, "windowFocusPointer");
                    events.mouseMove(target, target.width / 2, target.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    break;
                case 12:
                    var hint = test.find(panel, "windowFocusHint");
                    test.check(hint.visible, "Ctrl+Shift+click help appears on hover");
                    test.check(hint.text.indexOf(host.words.bringHint) >= 0, "localized help includes bring gesture");
                    test.check(hint.text.indexOf(host.words.chooseMoveHint) >= 0, "localized help describes the chooser separately");
                    console.info("WINDOWPEEK_TEST_PASS"); stop();
                    var image = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (image) window.contentItem.grabToImage(function(result) { result.saveToFile(image); Qt.quit(); });
                    else Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
