import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property int maps: 0
    property int frames: 0
    property int expandingFrames: 0
    property bool observing: false
    property var firstRow: null
    property real scrollPosition: 0
    property real originX: 0
    property real originY: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, text) { if (!value) throw new Error(text); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    readonly property var list: find(plugin.body, "windowList")
    TestEvent { id: events }
    FakeHost {
        id: host; bar: barApi; opened: plugin.opened
        Component.onCompleted: {
            savedAppearance = Appearance.normalize({uiScale:test.scale});
            var data = JSON.parse(JSON.stringify(snapshot));
            for (var i = 6; i <= 30; i++) data.clients.push({address:"0x"+i.toString(16),app:"Editor",class:"code",title:"Fictional transition document " + i,workspace:{id:4,name:"4"}});
            snapshot = data;
        }
    }
    Ui.PluginBarApi {
        id: barApi; pluginId: "sarr.windowpeek.transition.test"; position: "top"; barSize: 28
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item { id: anchor; x: 150; width: 130; height: 28 }
    }
    Window {
        id: probe; visible: true; width: 200; height: 100; title: "WindowPeek fictional transition test"
        Item { id: keyTarget; anchors.fill: parent; focus: true }
    }
    Plugin.Panel { id: plugin; bar: barApi; anchorItem: anchor; hostWidget: host }
    Connections {
        target: plugin.surface
        function onBackingWindowVisibleChanged() { if (plugin.mapped) test.maps++; }
    }
    Connections {
        target: plugin.surface.cardItem.Window.window
        function onFrameSwapped() {
            if (!test.observing) return;
            try {
                test.frames++;
                if (plugin.expansion > 0 && plugin.expansion < 1) test.expandingFrames++;
                test.check(plugin.mapped && test.maps === 1, "promotion remapped the surface");
                test.check(plugin.surface.cardItem.opacity === 1, "promotion faded the card");
                test.check(plugin.surface.cardItem.radius > 0, "promotion removed rounded corners");
                test.check(test.list.itemAtIndex(1) === test.firstRow, "promotion recreated a row");
                test.check(Math.abs(test.list.contentY - test.scrollPosition) < 1, "promotion changed scrolling");
                test.check(plugin.surface.cardOrigin.x === test.originX && plugin.surface.cardOrigin.y === test.originY,
                    "promotion moved its top-left anchor");
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); timer.stop(); Qt.quit(); }
        }
    }
    Timer {
        id: timer; interval: 360; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    if (!keyTarget.activeFocus && test.waits++ < 10) { test.step--; break; }
                    test.check(keyTarget.activeFocus, "probe ready");
                    plugin.hoverRequested = true; break;
                case 1:
                    test.check(plugin.hoverOpened && plugin.mapped, "hover maps");
                    test.check(plugin.body.searchField.activeFocus, "hover is ready for typing");
                    test.check(plugin.surface.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand, "hover keyboard mode");
                    test.check(plugin.surface.mask.width === Math.ceil(plugin.surface.cardItem.width), "hover input extends outside card");
                    test.check(!barApi.activePopout, "hover takes popup coordinator ownership");
                    test.firstRow = test.list.itemAtIndex(1);
                    test.list.contentY = 160; test.scrollPosition = test.list.contentY;
                    test.originX = plugin.surface.cardOrigin.x; test.originY = plugin.surface.cardOrigin.y;
                    test.observing = true; plugin.open(); break;
                case 2:
                    test.observing = false;
                    test.check(test.expandingFrames > 2, "promotion rendered intermediate sizes");
                    test.check(plugin.opened && !plugin.hoverOpened && plugin.mapped, "promotion state");
                    test.check(plugin.body.searchField.activeFocus, "promotion focuses search");
                    test.check(plugin.surface.focusPrimed && plugin.surface.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                        "expanded search retains keyboard focus");
                    test.check(plugin.surface.mask.width === Math.ceil(plugin.surface.cardItem.width), "expanded mouse input stays bounded to card");
                    test.check(barApi.activePopout === plugin, "expanded popup registers");
                    events.keyClick(Qt.Key_F, Qt.NoModifier, 0); break;
                case 3:
                    test.check(plugin.body.searchField.text === "f", "search receives typing immediately");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 4:
                    test.check(!plugin.mapped && !barApi.activePopout, "Escape releases surface and coordinator");
                    plugin.open(); break;
                case 5:
                    test.check(plugin.body.searchField.activeFocus && plugin.expansion === 1, "direct keyboard opening stays expanded");
                    plugin.close(); plugin.open(); break;
                case 6:
                    if (!plugin.body.searchField.activeFocus && test.waits++ < 15) { test.step--; break; }
                    test.check(plugin.opened && plugin.body.searchField.activeFocus, "rapid reopen restores focus");
                    plugin.close(); break;
                case 7:
                    test.check(!plugin.mapped, "final close unmaps");
                    console.info("WINDOWPEEK_TEST_PASS: single native surface; " + test.frames + " stable promotion frames");
                    stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
