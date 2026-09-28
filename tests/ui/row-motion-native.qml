import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int step: 0
    property int frames: 0
    property int reversals: 0
    property real largestReversal: 0
    property var previous: null
    property var row: null
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    FakeHost {
        id: host; bar: barApi; opened: panel.opened
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Ui.PluginBarApi {
        id: barApi; pluginId: "sarr.windowpeek.row-motion.test"; position: "top"; barSize: 28
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item { id: anchor; x: 150; width: 130; height: 28 }
    }
    Plugin.Panel { id: panel; bar: barApi; anchorItem: anchor; hostWidget: host }
    Connections {
        target: panel.surface.cardItem.Window.window
        function onFrameSwapped() {
            if (!test.row) return;
            var active = test.find(test.row, "activeWindowLabel");
            var move = test.find(test.row, "windowMoveLabel");
            var next = {progress:panel.expansion, active:active.mapToItem(test.row,0,0).x,
                move:move.mapToItem(test.row,0,0).x};
            var last = test.previous;
            if (last && next.progress !== last.progress) {
                test.frames++;
                var direction = next.progress > last.progress ? 1 : -1;
                for (var key of ["active", "move"]) {
                    var reversal = (last[key] - next[key]) * direction;
                    if (reversal > 0.001) { test.reversals++; console.info("ROW_REVERSAL", key, JSON.stringify(last), JSON.stringify(next), "width", panel.body.width, "overflow", test.find(panel.body,"windowList").contentHeight - test.find(panel.body,"windowList").height); }
                    test.largestReversal = Math.max(test.largestReversal, reversal);
                }
            }
            test.previous = next;
        }
    }
    Timer {
        id: sequence; interval: 300; repeat: true; running: true
        onTriggered: {
            try {
                if (test.step === 0) panel.hoverRequested = true;
                else if (test.step === 1) {
                    test.check(panel.mapped, "compact panel maps");
                    test.row = test.find(panel.body,"windowList").itemAtIndex(1);
                    panel.open();
                } else if (test.step < 27) {
                    test.check(panel.mapped && test.find(panel.body,"windowList").itemAtIndex(1) === test.row,
                        "animation preserves the surface and row");
                    // Complete cycles followed by reversals before settling.
                    if (test.step === 13) sequence.interval = 65;
                    if (test.step % 2 === 0) panel.collapse(); else panel.open();
                } else if (test.step === 27) sequence.interval = 300;
                else {
                    test.check(test.frames > 30, "enough presented animation frames: " + test.frames);
                    test.check(test.reversals === 0, "labels reversed " + test.reversals + " times; largest=" + test.largestReversal);
                    console.info("WINDOWPEEK_TEST_PASS: " + test.frames + " expansion/collapse frames, no label reversals");
                    panel.close(); stop(); Qt.quit();
                }
                test.step++;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); panel.close(); stop(); Qt.quit(); }
        }
    }
}
