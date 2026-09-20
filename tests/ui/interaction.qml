import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int updates: 0
    property var list: null
    property var pointer: null
    property var hint: null
    property var scrollbar: null
    property real stationarySize: 0
    property int transitions: 0
    property real previousY: 0
    property int hoverFrames: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function checkHover() {
        var point = list.mapToItem(list.contentItem, 40, 100);
        var chrome = find(list.itemAt(point.x, point.y), "windowFocus");
        check(!chrome || chrome.hovered, "window under the stationary pointer must stay highlighted while scrolling: step="
            + step + " contentY=" + list.contentY + " row=" + (chrome ? chrome.mapToItem(list, 0, 0) : "none"));
    }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        var children = item.data || item.children || [];
        for (var i = 0; i < children.length; i++) {
            var found = find(children[i], name);
            if (found) return found;
        }
        return null;
    }
    FakeHost {
        id: host
        settings: ({hintsMode: "on", scrollBounce: false})
        Component.onCompleted: {
            var data = JSON.parse(JSON.stringify(snapshot));
            data.clients = [];
            for (var i = 1; i <= 40; i++) data.clients.push({address: "0x" + i.toString(16), class: "code", app: "Editor",
                title: "Fictional document " + i, workspace: {id: Math.ceil(i / 4), name: String(Math.ceil(i / 4))}});
            snapshot = data;
        }
    }
    TestEvent { id: events }
    Window {
        id: window; color: Color.popups.background
        visible: true; width: 500 * test.scale; height: 460 * test.scale
        Rectangle { anchors.fill: parent; color: Color.popups.background }
        Plugin.PanelContent {
            id: panel; hostWidget: host; width: 500; height: 460
            scale: test.scale; transformOrigin: Item.TopLeft
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft; when: panel.QQC.Overlay.overlay !== null }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale; when: panel.QQC.Overlay.overlay !== null }
        }
    }
    Connections {
        target: test.pointer
        function onContainsMouseChanged() { test.transitions++; }
    }
    Connections {
        target: window
        // Qt updates hover immediately before rendering. A Timer can run
        // between the animation tick and that update, observing an unfinished frame.
        function onFrameSwapped() {
            if (test.step <= 30 || test.step > 50) return;
            try {
                test.checkHover(); test.hoverFrames++;
                test.check(Math.abs(test.list.contentItem.y - Math.round(test.list.contentItem.y)) < 0.001,
                    "thin row borders must stay aligned to pixels while scrolling");
            }
            catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); Qt.quit(); }
        }
    }
    Timer {
        interval: 35; running: test.step > 0; repeat: true
        onTriggered: {
            var data = JSON.parse(JSON.stringify(host.snapshot));
            test.updates++;
            data.clients.forEach(function(client) { client.title = (test.updates % 2 ? "Short " : "A very long fictional title ".repeat(20)) + test.updates; });
            host.snapshot = data;
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (test.step === 0) {
                    panel.begin();
                    test.list = test.find(panel, "windowList");
                    test.scrollbar = test.find(panel, "windowScrollbar");
                    test.stationarySize = test.scrollbar.size;
                    test.pointer = test.find(panel, "windowFocusPointer");
                    test.hint = test.find(panel, "windowFocusHint");
                    events.mouseMove(test.pointer, 40, 20, 0, Qt.NoButton, Qt.NoModifier);
                    test.transitions = 0;
                }
                if (test.step > 0 && test.step < 15) {
                    test.check(Math.abs(test.scrollbar.size - test.stationarySize) < 0.0001,
                        "title updates change the resting scrollbar size: " + test.stationarySize + " -> " + test.scrollbar.size);
                    test.check(!test.scrollbar.active, "title updates activate the resting scrollbar");
                    test.check(test.pointer.containsMouse && test.transitions === 0,
                        "stationary row loses hover: step=" + test.step + " transitions=" + test.transitions);
                }
                if (test.step === 15) {
                    test.check(test.hint.visible, "row hint appears while stationary");
                    test.list.contentY = 70;
                    events.mouseMove(test.list, 40, 1, 0, Qt.NoButton, Qt.NoModifier);
                    test.transitions = 0;
                }
                if (test.step > 15 && test.step < 30) {
                    test.check(test.pointer.containsMouse && test.transitions === 0,
                        "clipped row loses hover: step=" + test.step + " transitions=" + test.transitions);
                }
                if (test.step === 30) {
                    events.mouseMove(test.list, 40, 100, 0, Qt.NoButton, Qt.NoModifier);
                    events.mouseWheel(test.list, 40, 100, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                    test.check(test.list.moving, "wheel starts scrolling before hover is checked");
                }
                if (test.step > 30 && test.step <= 50) {
                    test.check(Math.abs(test.scrollbar.size - test.stationarySize) < 0.0001,
                        "scrolling unchanged data must not resize the scrollbar");
                    test.check(test.scrollbar.contentItem.color.a > 0.6,
                        "scrollbar dims between consecutive wheel events: alpha=" + test.scrollbar.contentItem.color.a);
                    test.check(test.list.contentY >= test.previousY - 1, "downward wheel progress reverses during title changes");
                    test.check(panel.searchField.activeFocus, "title changes and wheel input retain search focus");
                    test.previousY = test.list.contentY;
                    events.mouseWheel(test.list, 40, 100, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                }
                if (test.step === 55) {
                    test.check(test.hoverFrames > 20, "hover is checked on rendered scrolling frames");
                    test.check(test.list.contentY > test.list.height * 2, "wheel crosses several workspace sections: y=" + test.list.contentY + " end=" + (test.list.contentHeight - test.list.height) + " moving=" + test.list.moving);
                    test.check(Math.abs(test.scrollbar.contentItem.color.a - 0.7) < 0.01, "scrollbar remains visible after wheel input stops");
                    test.previousY = test.list.contentY;
                }
                if (test.step > 55 && test.step <= 80) {
                    test.check(test.list.contentY <= test.previousY + 1, "upward wheel progress reverses during title changes");
                    test.previousY = test.list.contentY;
                    events.mouseWheel(test.list, 40, 100, Qt.NoButton, Qt.NoModifier, 0, 120, 0);
                }
                if (test.step === 85) {
                    test.list.cancelFlick(); test.list.positionViewAtBeginning();
                }
                if (test.step === 87) {
                    test.pointer = test.find(test.list.itemAtIndex(1), "windowMovePointer");
                    test.hint = test.find(test.list.itemAtIndex(1), "windowMoveHint");
                    events.mouseMove(test.pointer, 20, 20, 0, Qt.NoButton, Qt.NoModifier);
                    test.transitions = 0;
                }
                if (test.step > 87 && test.step <= 100) {
                    test.check(test.pointer.containsMouse && test.transitions === 0, "Move hover stays stable during title changes");
                }
                if (test.step === 100 && Quickshell.env("WINDOWPEEK_TEST_IMAGE"))
                    window.contentItem.grabToImage(function(result) { result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); });
                if (test.step === 101) {
                    test.check(test.hint.visible, "Move hint appears after scrolling stops");
                    panel.dismiss();
                    test.check(!test.hint.visible, "closing the panel dismisses its hints");
                }
                if (test.step === 102) {
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
                test.step++;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
