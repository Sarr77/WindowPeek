import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

// A preview must keep number shortcuts and ordinary search input on its source.
ShellRoot {
    id: test
    property int step: 0
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    TestEvent { id: events }
    FakeHost { id: host; windowPreview: thumbnail; settings: ({previewHoverDelay:0}) }
    FloatingWindow {
        id: window; visible: true; implicitWidth: 1000; implicitHeight: 700
        Plugin.PanelContent { id: panel; width: 500; height: 650; hostWidget: host }
    }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget: host; shortcutTarget: panel.previewKeyTarget }
    Timer {
        interval: 180; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: thumbnail.modifierState.enabled = false; panel.begin(); break;
                case 1:
                    thumbnail.showFor(test.find(panel, "windowFocusPointer"), "0x1", panel);
                    thumbnail.modifierState.pending = "fixture";
                    thumbnail.modifierState.receive("custom", "windowpeek-preview-shift,fixture,0"); break;
                case 2:
                    test.check(thumbnail.visible && thumbnail.backingWindowVisible, "preview is mapped");
                    thumbnail.contentItem.Window.window.requestActivate();
                    thumbnail.contentItem.forceActiveFocus(); break;
                case 3:
                    test.check(thumbnail.contentItem.activeFocus, "preview receives keyboard events");
                    events.keyClick(Qt.Key_2, Qt.ControlModifier, 0);
                    test.check(host.focused === "0x2", "preview forwards Ctrl+digit to the source list");
                    events.keyRelease(Qt.Key_Control, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_A, Qt.NoModifier, 0);
                    test.check(panel.searchField.text.toLowerCase() === "a", "preview preserves typing into the focused search field: " + panel.searchField.text);
                    panel.searchField.text = ""; panel.selectedAddress = "0x1"; break;
                case 4:
                    events.keyClick(Qt.Key_Right, Qt.NoModifier, 0);
                    test.check(thumbnail.shortcutTarget.objectName === "windowMove", "Right changes the source action to Move: " + JSON.stringify({
                        target:thumbnail.shortcutTarget.objectName, active:window.activeFocusItem ? window.activeFocusItem.objectName : null,
                        search:panel.searchField.focus, row:test.find(panel,"windowMove").focus}));
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(panel.mode === "move" && panel.moveAddress === "0x1", "Enter uses the newly focused Move action");
                    console.info("WINDOWPEEK_TEST_PASS: preview forwards shortcuts, search input and row navigation"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
