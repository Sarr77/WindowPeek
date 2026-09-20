import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: -1
    property int waits: 0
    property int returns: 0
    property int maps: 0
    property bool watching: false
    property var panel: null
    property var button: null
    property var bridge: null
    property var list: null
    property var firstRow: null
    property real scrollPosition: 0
    property int hintsUsed: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function fail(message) { console.error("WINDOWPEEK_TEST_FAIL: " + message); timer.stop(); Qt.quit(); }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) >= 0) return null;
        seen.push(object);
        if (object.objectName === name) return object;
        var children = [];
        if (object.data) for (var child of object.data) children.push(child);
        if (object.item) children.push(object.item);
        if (object.contentItem) children.push(object.contentItem);
        if (object.children) for (var child of object.children) children.push(child);
        for (var child of children) { var found = find(child, name, seen); if (found) return found; }
        return null;
    }
    function move(item, x, y) {
        check(!mover.running, "previous pointer move is unfinished");
        var point = item.mapToGlobal(x, y);
        mover.target = item; mover.point = Qt.point(x, y);
        mover.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x="
            + Math.round(point.x) + ",y=" + Math.round(point.y) + "}))"];
        mover.running = true;
    }
    TestEvent { id: events }
    Process {
        id: mover
        property var target: null
        property point point
        onExited: function(code) {
            if (code !== 0) { test.fail("native pointer move failed"); return; }
            // Cursor warps update native surface entry but can omit motion within
            // that surface. Deliver the matching Qt event at the parked position.
            events.mouseMove(target, point.x, point.y, 0, Qt.NoButton, Qt.NoModifier);
        }
    }
    FakeHost { id: data }
    Plugin.WindowState { id: fictionalState; enabled: false; snapshot: data.snapshot }
    QtObject { id: fakeShell; function updateEntryInline(id, values) { return true; } }
    Ui.PluginBarApi {
        id: api; pluginId: "sarr.windowpeek.return.test"; moduleName: "sarr.windowpeek"
        position: "top"; barSize: 28; shell: fakeShell
        layoutConfig: ({left:[{id:"sarr.windowpeek", hintsMode:"auto", hintsUsed:0,
            uiScale:test.scale, windowPreviews:false, autoUpdates:false}], center:[], right:[]})
        _moduleWidgets: function() { return loader.item ? [loader.item] : []; }
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        Loader { id: loader; x: 140; active: false; sourceComponent: Plugin.Widget { bar: api } }
    }
    Component.onCompleted: {
        var state = Plugin.Runtime.state;
        state.enabled = false; state.pending = false; state.coalesce.stop(); state.reader.running = false;
        Plugin.Runtime.state = fictionalState;
        var snapshot = JSON.parse(JSON.stringify(data.snapshot));
        for (var i = 6; i < 28; ++i) snapshot.clients.push({address:"0x"+i.toString(16), class:"code", title:"Fictional return " + i, workspace:{id:1,name:"1"}});
        data.snapshot = snapshot;
    }
    Connections {
        target: test.panel ? test.panel.surface : null
        function onBackingWindowVisibleChanged() {
            if (test.panel.mapped) test.maps++;
            if (test.watching && (!test.panel.mapped || test.maps !== 1)) test.fail("return remapped the panel");
        }
    }
    Connections {
        target: test.panel ? test.panel.surface.cardItem : null
        function onOpacityChanged() {
            if (test.watching && test.panel.surface.cardItem.opacity < 0.999) test.fail("return faded the panel");
        }
    }
    Timer {
        id: timer; interval: 200; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case -1:
                    test.move(bar.contentItem, bar.width - 30, 70);
                    loader.active = true; break;
                case 0:
                    if (!loader.item || !loader.item.settingsReady) { test.check(test.waits++ < 20, "widget ready"); test.step--; break; }
                    test.panel = test.find(loader.item, "windowPeekController", []);
                    test.button = test.find(loader.item, "windowPeekBarButton", []);
                    test.check(test.panel && test.button, "production widget and controller loaded");
                    test.bridge = test.find(test.panel.surface, "windowPeekBarBridge", []);
                    test.list = test.find(test.panel.body, "windowList", []);
                    test.panel.surface.gap = 12;
                    test.move(test.button, test.button.width / 2, test.button.height / 2); break;
                case 1:
                    test.check(!test.panel.hoverOpened, "first entry still observes the dwell delay"); break;
                case 2: break;
                case 3:
                    test.check(test.panel.hoverOpened && test.maps === 1, "initial hover opens once");
                    test.hintsUsed = loader.item.hints.used;
                    test.list.contentY = 120; test.scrollPosition = test.list.contentY;
                    test.firstRow = test.list.itemAtIndex(1); test.watching = true;
                    test.move(test.bridge, test.bridge.width / 2, test.bridge.height / 2); break;
                case 4:
                    test.check(test.panel.surface.barBridgeHovered && !loader.item.canShowTooltip, "native pointer entered the bridge and left the label");
                    test.move(test.panel.surface.cardItem, 25, 12); break;
                case 5:
                    test.check(!test.panel.surface.barBridgeHovered && !test.panel.canHideHover, "native pointer entered the card: " + JSON.stringify({
                        gapHover:test.panel.surface.barBridgeHovered, canHide:test.panel.canHideHover,
                        requested:test.panel.hoverRequested, barHover:loader.item.canShowTooltip,
                        gap:[test.bridge.x,test.bridge.y,test.bridge.width,test.bridge.height],
                        card:[test.panel.surface.cardItem.x,test.panel.surface.cardItem.y,test.panel.surface.cardItem.width,test.panel.surface.cardItem.height],
                        mask:[test.panel.surface.mask.x,test.panel.surface.mask.y,test.panel.surface.mask.width,test.panel.surface.mask.height]}));
                    test.move(test.bridge, test.bridge.width / 2, test.bridge.height / 2); break;
                case 6:
                    test.check(test.panel.surface.barBridgeHovered, "native pointer returned to gap");
                    test.move(test.button, test.button.width / 2, test.button.height / 2); break;
                case 7: case 8: case 9:
                    test.check(loader.item.canShowTooltip && !test.panel.surface.barBridgeHovered, "native pointer returned to the actual label");
                    test.check(test.panel.hoverOpened && test.panel.mapped && test.maps === 1, "label retains the same panel beyond both timers");
                    test.check(loader.item.hints.used === test.hintsUsed, "return does not consume another hint");
                    test.check(test.list.itemAtIndex(1) === test.firstRow && test.list.contentY === test.scrollPosition, "return preserves row identity and scroll");
                    if (test.step === 10 && ++test.returns < 3) test.step = 3;
                    break;
                case 10:
                    test.button.triggerPress(Qt.LeftButton); break;
                case 11:
                    test.check(test.panel.opened && test.panel.body.searchField.activeFocus && test.maps === 1, "label click promotes without remapping");
                    test.watching = false; loader.item.actionOnClose = true; loader.item.close();
                    test.move(test.button, test.button.width + 40, bar.screen.height - 40); break;
                case 12: break;
                case 13:
                    test.check(!test.panel.mapped, "explicit close still unmaps");
                    console.info("WINDOWPEEK_TEST_PASS: three native label/card returns, no fade/remap, stable scroll/hints, click promotion");
                    timer.stop(); Qt.quit();
                }
            } catch (error) { test.fail(error); }
        }
    }
}
