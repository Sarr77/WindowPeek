import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int revision: 0
    property real lastY: 0
    property var list: null
    property var firstRow: null
    property int hoverFrames: 0
    readonly property bool testPanel: Quickshell.env("WINDOWPEEK_TEST_SURFACE") === "panel"
    readonly property var surface: testPanel ? panel : preview
    readonly property string rowName: testPanel ? "windowFocusPointer" : "windowFocusPointer"
    property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function checkHover(item) {
        if (item.objectName === rowName) {
            var point = list.mapToItem(item, 40, 100);
            if (point.x >= 0 && point.x < item.width && point.y >= 0 && point.y < item.height)
                check(item.parent.hovered, "window under the pointer loses its hover while scrolling: step=" + test.step
                    + " y=" + test.list.contentY + " row=" + item.parent.parent.window.address
                    + " point=" + point.x + "," + point.y + " contains=" + item.containsMouse
                    + " lastMouse=" + item.mouseX + "," + item.mouseY + " height=" + item.height
                    + " scene=" + list.mapToItem(testWindow.contentItem, 40, 100));
        }
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) checkHover(children[i]);
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) {
            var found = find(children[i], name);
            if (found) return found;
        }
        return null;
    }
    TestEvent { id: events }
    FakeHost {
        id: host; includeSpecial: true
        Component.onCompleted: {
            savedAppearance = Appearance.normalize({uiScale: test.scale, tooltipStyle: Quickshell.env("WINDOWPEEK_TEST_STYLE")});
            var data = JSON.parse(JSON.stringify(snapshot));
            data.clients = [];
            for (var i = 1; i <= 10; i++) data.clients.push({address: "0x" + i.toString(16), class:"code", app:"Editor",
                title:"Fictional document " + i, workspace:i <= 4 ? {id:1,name:"1"} : {id:-99,name:"special:scratchpad"}});
            snapshot = data;
        }
    }
    Window {
        id: testWindow
        visible: true; width: (test.testPanel ? 500 : preview.implicitWidth) * test.scale
        height: (test.testPanel ? 460 : preview.implicitHeight) * test.scale
        Plugin.PanelContent {
            id: panel; hostWidget: host; visible: test.testPanel
            width: 500; height: 460; scale: test.scale; transformOrigin: Item.TopLeft
        }
        Plugin.TooltipContent {
            id: preview; hostWidget: host; visible: !test.testPanel
            width: implicitWidth; height: implicitHeight; maximumHeight: Math.min(560, 980 / test.scale)
            scale: test.scale; transformOrigin: Item.TopLeft
        }
    }
    Connections {
        target: testWindow
        function onFrameSwapped() {
            if (!test.list || test.step < 7 || test.step > 20) return;
            try {
                test.check(Math.abs(test.list.contentItem.y - Math.round(test.list.contentItem.y)) < 0.001,
                    "scrolling keeps thin borders aligned to pixels");
                // Wheel delivery and animation can move geometry before Qt's
                // next hover update. Compare the state at the rendered frame.
                if (test.step >= 8) {
                    test.checkHover(test.surface);
                    test.hoverFrames++;
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); Qt.quit(); }
        }
    }
    // A terminal can change its title while wheel animation is still in flight.
    Timer {
        interval: 35; repeat: true; running: test.step >= 2 && test.step <= 24
        onTriggered: {
            var data = JSON.parse(JSON.stringify(host.snapshot));
            data.clients[0].title = "Fictional progress " + (++test.revision);
            host.snapshot = data;
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (test.step === 0) {
                    if (test.testPanel) panel.begin();
                    test.list = test.find(test.surface, test.testPanel ? "windowList" : "windowList");
                    test.check(test.list && test.list.contentHeight > test.list.height, "ten-window fixture overflows");
                }
                if (test.step === 1) {
                    test.firstRow = test.find(test.surface, test.rowName);
                    events.mouseMove(test.firstRow, 40, 20, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(test.firstRow.containsMouse, "hover starts on first window");
                }
                if (test.step >= 2 && test.step <= 24) {
                    if (test.testPanel) test.check(panel.searchField.activeFocus, "panel lost keyboard focus during scrolling");
                    if (test.step < 7 || !test.testPanel)
                        test.check(test.firstRow === test.find(test.surface, test.rowName), "refresh replaced the hovered window control");
                    if (test.step < 7) test.check(test.firstRow.containsMouse, "stationary pointer loses its highlight during refresh");
                    // An intentional edge rebound can reverse overshoot; ordinary
                    // scrolling must still progress through the actual content.
                    var end = test.list.originY + test.list.contentHeight - test.list.height;
                    var progress = Math.max(test.list.originY, Math.min(end, test.list.contentY));
                    test.check(progress >= test.lastY - 1, "refresh rewound wheel scrolling: " + test.lastY + " -> " + progress);
                    test.lastY = progress;
                    if (test.step >= 7 && test.step <= 20) {
                        if (test.step === 7) events.mouseMove(test.list, 40, 100, 0, Qt.NoButton, Qt.NoModifier);
                        events.mouseWheel(test.list, 40, 100, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                    }
                }
                if (test.step === 25) {
                    test.check(test.hoverFrames > 5, "hover sampled across rendered scroll frames");
                    test.check(test.list.atYEnd, "continuous wheel scrolling reaches the end during live updates");
                    test.list.cancelFlick();
                    if (test.testPanel) test.list.positionViewAtBeginning();
                    else preview.resetScroll();
                    host.persistSettings({scrollBounce: true});
                    test.list.flick(0, 900);
                }
                if (test.step === 26) {
                    test.check(test.list.contentY < test.list.originY - 1, "enabled spring effect overshoots the top edge");
                    host.persistSettings({scrollBounce: false});
                }
                if (test.step === 32) {
                    test.check(Math.abs(test.list.contentY - test.list.originY) < 1, "disabling during rebound settles at the edge");
                    test.list.flick(0, 900);
                }
                if (test.step === 33) {
                    test.check(Math.abs(test.list.contentY - test.list.originY) < 1, "disabled spring effect stays within bounds");
                    host.persistSettings({scrollBounce: true});
                    test.list.flick(0, 900);
                }
                if (test.step === 34) {
                    test.check(test.list.contentY < test.list.originY - 1, "spring effect can be enabled again");
                }
                if (test.step === 42) {
                    test.check(Math.abs(test.list.contentY - test.list.originY) < 1 && !test.list.moving,
                        "native spring returns to rest at the edge");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
                test.step++;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
