import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int toggles: 0
    property int closes: 0
    property var list: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    TestEvent { id: events }
    FakeHost {
        id: host
        Component.onCompleted: {
            var data = JSON.parse(JSON.stringify(snapshot));
            for (var i = 6; i <= 40; ++i) data.clients.push({address:"0x" + i.toString(16),class:"code",
                title:"Fictional background test " + i,workspace:{id:4,name:"4"}});
            snapshot = data;
        }
    }
    Window {
        visible: true; width: 500 * test.scale; height: 480 * test.scale
        Plugin.PanelContent {
            id: panel; hostWidget: host; width: 500; height: 480
            scale: test.scale; transformOrigin: Item.TopLeft
            onBackgroundClicked: test.toggles++
            onCloseRequested: test.closes++
        }
    }
    Timer {
        interval: 180; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.begin(); test.list = test.find(panel, "windowList"); break;
                case 1:
                    events.mouseClick(test.list.itemAtIndex(0), 80, 12, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.toggles === 1, "workspace heading counts as background");
                    events.mouseClick(test.list.itemAtIndex(0), 80, 12, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.check(test.toggles === 1, "modified background click does not toggle");
                    events.mouseClick(test.list.itemAtIndex(1), 30, 20, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(host.focused === "0x1" && test.toggles === 1, "row retains its action");
                    events.mouseClick(test.list.itemAtIndex(1), 30, 20, Qt.LeftButton, Qt.ControlModifier | Qt.ShiftModifier, 0);
                    test.check(host.brought === "0x1" && test.toggles === 1, "Ctrl+Shift+click retains bring action");
                    host.focused = ""; host.brought = "";
                    events.mouseClick(test.list.itemAtIndex(1), 30, 20, Qt.RightButton, Qt.NoModifier, 0);
                    test.check(test.closes === 1 && !host.focused && !host.brought && test.toggles === 1,
                        "right-click on an expanded row closes without activating or toggling it");
                    events.mouseClick(panel.searchField, 80, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(panel.searchField.activeFocus && test.toggles === 1, "search does not toggle");
                    events.mouseWheel(test.list, 70, 12, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                    break;
                case 3:
                    test.check(test.list.contentY > 0 && test.toggles === 1, "wheel on blank heading scrolls without toggling");
                    test.list.cancelFlick(); test.list.contentY = 0;
                    events.mousePress(test.list, 80, 12, Qt.LeftButton, Qt.NoModifier, 0);
                    events.mouseMove(test.list, 80, -20, 0, Qt.LeftButton, Qt.NoModifier);
                    events.mouseMove(test.list, 80, -65, 0, Qt.LeftButton, Qt.NoModifier);
                    events.mouseRelease(test.list, 80, -65, Qt.LeftButton, Qt.NoModifier, 0);
                    break;
                case 5:
                    test.check(test.toggles === 1, "drag starting in background does not toggle");
                    test.list.cancelFlick(); test.list.contentY = 0;
                    var row = test.list.itemAtIndex(1);
                    events.mouseClick(row, row.width - 20, 20, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(panel.mode === "move" && test.toggles === 1, "Move does not fall through");
                    panel.back();
                    events.mouseClick(test.find(panel, "settingsButton"), 20, 12, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(panel.mode === "settings" && test.toggles === 1, "Settings does not fall through");
                    panel.back(); panel.expanded = false;
                    break;
                case 6:
                    events.mouseClick(test.list.itemAtIndex(0), 80, 12, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.toggles === 2, "collapsed list also accepts background clicks");
                    events.mouseClick(test.list.itemAtIndex(1), 30, 20, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.toggles === 2, "collapsed window row does not fall through");
                    var scrollbar = test.find(panel, "windowScrollbar");
                    events.mousePress(scrollbar, scrollbar.width / 2, 4, Qt.LeftButton, Qt.NoModifier, 0);
                    events.mouseMove(scrollbar, scrollbar.width / 2, scrollbar.height / 2, 0, Qt.LeftButton, Qt.NoModifier);
                    events.mouseRelease(scrollbar, scrollbar.width / 2, scrollbar.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.toggles === 2, "scrollbar dragging does not toggle");
                    var header = test.find(panel, "panelHeader");
                    events.mouseClick(header, 20, 12, Qt.RightButton, Qt.NoModifier, 0);
                    test.check(test.closes === 2 && test.toggles === 2, "right-click on the hover header closes instead of expanding");
                    console.info("WINDOWPEEK_TEST_PASS: background input routing"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
