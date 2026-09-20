import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int revision: 0
    property int transitions: 0
    property int waits: 0
    property var body: null
    property var list: null
    property var pointer: null
    property real previousY: 0
    property var observed: []
    property int hoverEvents: 0
    property int invalidExits: 0
    property int geometryChanges: 0
    property real lastHeight: 0
    property int hoverFrames: 0
    property real minimumHoverAlpha: 1
    property real maximumHoverAlpha: 0
    property int fractionalFrames: 0
    Connections {
        target: test.list ? test.list.Window.window : null
        function onFrameSwapped() {
            if (test.manual || test.step < 50 || test.step >= 69) return;
            if (Math.abs(test.list.contentItem.y - Math.round(test.list.contentItem.y)) > 0.001) test.fractionalFrames++;
            var row = test.find(test.list.itemAt(40, test.list.contentY + 100), "windowFocus", []);
            if (!row || !row.hovered) return;
            test.hoverFrames++;
            test.minimumHoverAlpha = Math.min(test.minimumHoverAlpha, row.color.a);
            test.maximumHoverAlpha = Math.max(test.maximumHoverAlpha, row.color.a);
        }
    }
    readonly property bool manual: Quickshell.env("WINDOWPEEK_TEST_MANUAL") === "1"
    property point cursorPoint: Qt.point(40, 100)
    property var scrollbar: null
    property string lastScrollState: ""
    Timer {
        interval: 16; running: test.manual && !!test.scrollbar; repeat: true
        onTriggered: {
            var bar = test.scrollbar;
            var state = JSON.stringify({hover:bar.hovered, pressed:bar.pressed, active:bar.active,
                thumb:bar.contentItem.color.a, track:bar.background.color.a, size:bar.size});
            if (state !== test.lastScrollState) {
                test.lastScrollState = state;
                console.info("SCROLL_TRACE", Date.now(), state);
            }
        }
    }
    function observe(item) {
        if (!item) return;
        if (["windowFocusPointer", "windowMovePointer"].indexOf(item.objectName) >= 0 && observed.indexOf(item) < 0) {
            observed.push(item);
            var record = function() {
                if (!test.manual && (test.step < 50 || test.step >= 69)) return;
                var p = item.mapToItem(test.list, 0, 0);
                var c = test.cursorPoint;
                var inside = c.x > p.x + 2 && c.x < p.x + item.width - 2
                    && c.y > p.y + 2 && c.y < p.y + item.height - 2;
                test.hoverEvents++;
                if (!item.containsMouse && inside) test.invalidExits++;
                console.info("HOVER_TRACE", JSON.stringify({step:test.step, hover:item.containsMouse,
                    inside:inside, y:p.y, h:item.height, contentY:test.list.contentY,
                    contentHeight:test.list.contentHeight, localY:item.mouseY,
                    time:Date.now(), item:String(item), cursor:c}));
            };
            item.entered.connect(record);
            item.exited.connect(record);
            if (test.manual) item.positionChanged.connect(function() {
                test.cursorPoint = item.mapToItem(test.list, item.mouseX, item.mouseY);
            });
        }
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) observe(children[i]);
    }
    FrameAnimation {
        running: !test.manual && test.step >= 49 && test.step < 69
        onTriggered: {
            test.observe(test.list.contentItem);
            if (test.lastHeight && test.lastHeight !== test.list.contentHeight) test.geometryChanges++;
            test.lastHeight = test.list.contentHeight;
        }
    }
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) >= 0) return null;
        seen.push(object);
        if (object.objectName === name) return object;
        var children = [];
        if (object.data) for (var i = 0; i < object.data.length; i++) children.push(object.data[i]);
        if (object.contentItem) children.push(object.contentItem);
        if (object.children) for (var j = 0; j < object.children.length; j++) children.push(object.children[j]);
        for (var k = 0; k < children.length; k++) { var found = find(children[k], name, seen); if (found) return found; }
        return null;
    }
    function move(item, x, y) {
        var position = item.mapToGlobal(x, y);
        mover.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x=" + Math.round(position.x) + ",y=" + Math.round(position.y) + "}))"];
        mover.running = true;
    }
    TestEvent { id: events }
    Process { id: mover }
    FakeHost {
        id: host; bar: barApi
        settings: ({hintsMode: Quickshell.env("WINDOWPEEK_TEST_HINTS") || "on", scrollBounce: false})
        Component.onCompleted: {
            savedAppearance = Appearance.normalize({uiScale: test.scale});
            var data = JSON.parse(JSON.stringify(snapshot));
            data.clients = [];
            for (var i = 1; i <= 40; i++) data.clients.push({address: "0x" + i.toString(16), class: "code", app: "Editor",
                title: "Fictional document " + i, workspace: {id: Math.ceil(i / 4), name: String(Math.ceil(i / 4))}});
            snapshot = data;
        }
    }
    Ui.PluginBarApi {
        id: barApi; pluginId: "sarr.windowpeek.test"; moduleName: plugin.moduleName
        position: "top"; barSize: 28
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item { id: anchor; x: 100; width: 130; height: 28 }
    }
    Plugin.Panel { id: plugin; bar: barApi; anchorItem: anchor; hostWidget: host }
    Connections { target: test.pointer; function onContainsMouseChanged() { test.transitions++; } }
    Timer {
        interval: 35; running: !test.manual && test.step > 1; repeat: true
        onTriggered: {
            var data = JSON.parse(JSON.stringify(host.snapshot));
            test.revision++;
            data.clients.forEach(function(client) { client.title = (test.revision % 2 ? "Short " : "A long fictional title ".repeat(20)) + test.revision; });
            host.snapshot = data;
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (test.step === 0) { plugin.open(); test.body = test.find(plugin, "windowPeekContent", []); }
                if (test.manual && test.step >= 3) {
                    if (!test.list) {
                        test.list = test.find(test.body, "windowList", []);
                        test.scrollbar = test.find(test.body, "windowScrollbar", []);
                    }
                    test.observe(test.list.contentItem);
                    if (test.step++ >= 750) {
                        console.info("HOVER_SUMMARY", JSON.stringify({events:test.hoverEvents,invalidExits:test.invalidExits}));
                        console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                    }
                    return;
                }
                if (test.step === 3) {
                    test.list = test.find(test.body, "windowList", []);
                    test.list.positionViewAtBeginning();
                    test.pointer = test.find(test.list.itemAtIndex(1), "windowFocusPointer", []);
                    if (!test.pointer && test.waits++ < 20) return;
                    test.check(test.pointer, "first native row is materialized");
                    test.move(test.pointer, 40, 20);
                }
                if (test.step === 5) {
                    events.mouseMove(test.pointer, 40, 20, 0, Qt.NoButton, Qt.NoModifier);
                    test.transitions = 0;
                }
                if (test.step > 5 && test.step < 25) {
                    test.check(test.pointer.containsMouse && test.transitions === 0,
                        "native stationary hover changes: step=" + test.step + " transitions=" + test.transitions
                        + " target=" + test.pointer.mapToGlobal(40, 20) + " local=" + test.pointer.mouseX + "," + test.pointer.mouseY);
                    test.check(test.body.searchField.activeFocus, "native search loses focus");
                }
                if (test.step === 25) {
                    test.list.contentY = 70;
                    test.move(test.list, 40, 1);
                }
                if (test.step === 27) {
                    events.mouseMove(test.list, 40, 1, 0, Qt.NoButton, Qt.NoModifier);
                    test.transitions = 0;
                }
                if (test.step > 27 && test.step < 47) {
                    test.check(test.pointer.containsMouse && test.transitions === 0,
                        "native clipped hover changes: step=" + test.step + " transitions=" + test.transitions);
                }
                if (test.step === 47) test.move(test.list, 40, 100);
                if (test.step >= 49 && test.step < 69) {
                    if (test.step === 49) events.mouseMove(test.list, 40, 100, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(test.list.contentY >= test.previousY - 1, "native wheel reverses during title refresh");
                    test.previousY = test.list.contentY;
                    events.mouseWheel(test.list, 40, 100, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                }
                if (test.step === 75) {
                    console.info("HOVER_SUMMARY", JSON.stringify({events:test.hoverEvents,invalidExits:test.invalidExits,geometryChanges:test.geometryChanges,
                        frames:test.hoverFrames,minAlpha:test.minimumHoverAlpha,maxAlpha:test.maximumHoverAlpha,
                        fractionalFrames:test.fractionalFrames}));
                    test.check(test.list.contentY > 500, "native wheel traverses multiple workspaces");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
                test.step++;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
