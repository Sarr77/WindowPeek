import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int side: 0
    readonly property var sides: ["top", "bottom", "left", "right"]
    readonly property bool horizontal: side < 2
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var surface: panel.surface
    readonly property var bridge: surface.cardItem.Window.window
        ? find(surface.cardItem.Window.window.contentItem, "windowPeekBarBridge") : null
    function check(value, message) { if (!value) throw new Error(sides[side] + ": " + message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function insideMask(x, y) {
        var mask = surface.mask;
        return x >= mask.x && y >= mask.y && x < mask.x + mask.width && y < mask.y + mask.height;
    }
    function enterGap() { events.mouseMove(bridge, bridge.width / 2, bridge.height / 2, 0, Qt.NoButton, Qt.NoModifier); }
    TestEvent { id: events }
    FakeHost {
        id: host; bar: barApi; opened: panel.opened
        settings: ({hintsMode:"off"})
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Ui.PluginBarApi { id: barApi; pluginId: "sarr.windowpeek.bridge.test"; position: test.sides[test.side]; barSize: 28 }
    PanelWindow {
        id: bar
        anchors {
            top: barApi.position !== "bottom"; bottom: barApi.position !== "top"
            left: barApi.position !== "right"; right: barApi.position !== "left"
        }
        implicitWidth: 28; implicitHeight: 28
        color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item {
            id: anchor
            x: test.horizontal ? 130 : 0; y: test.horizontal ? 0 : 130
            width: test.horizontal ? 130 : 28; height: test.horizontal ? 28 : 130
        }
    }
    Plugin.Panel {
        id: panel; bar: barApi; anchorItem: anchor; hostWidget: host
        Component.onCompleted: surface.gap = 12
    }
    Timer {
        id: timer; interval: 200; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.hoverRequested = true; break;
                case 1:
                    test.check(panel.mapped && test.bridge.enabled, "hover exposes the gap");
                    test.check(test.bridge.width > 0 && test.bridge.height > 0, "nonempty bridge");
                    var x = test.bridge.x + test.bridge.width / 2, y = test.bridge.y + test.bridge.height / 2;
                    test.check(test.insideMask(x, y), "native input mask includes the gap");
                    if (test.side === 0) test.check(!test.insideMask(x, bar.height - 1), "top bar remains reachable");
                    if (test.side === 1) test.check(!test.insideMask(x, surface.screenH - bar.height), "bottom bar remains reachable");
                    if (test.side === 2) test.check(!test.insideMask(bar.width - 1, y), "left bar remains reachable");
                    if (test.side === 3) test.check(!test.insideMask(surface.screenW - bar.width, y), "right bar remains reachable");
                    test.enterGap(); panel.hoverRequested = false; break;
                case 2: case 3: case 4: case 5: case 6:
                    test.check(surface.barBridgeHovered && panel.hoverOpened && panel.mapped,
                        "stationary pointer in gap must retain hover beyond the leave delay");
                    test.check(!panel.opened && !barApi.activePopout, "gap never expands or claims the bar");
                    break;
                case 7:
                    events.mouseClick(test.bridge, test.bridge.width / 2, test.bridge.height / 2, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.check(!host.focused && !host.brought && !host.moved, "gap has no window action");
                    events.mouseMove(surface.cardItem, surface.cardItem.width / 2, 10, 0, Qt.NoButton, Qt.NoModifier); break;
                case 8:
                    test.check(panel.hoverOpened && panel.mapped && !surface.barBridgeHovered, "gap to card retains hover");
                    test.enterGap(); break;
                case 9:
                    test.check(panel.hoverOpened && surface.barBridgeHovered, "card to gap retains hover");
                    // Exit along the panel edge, outside both the bridge and the card.
                    events.mouseMove(test.bridge, test.horizontal ? -10 : test.bridge.width / 2,
                        test.horizontal ? test.bridge.height / 2 : -10, 0, Qt.NoButton, Qt.NoModifier); break;
                case 10: break; // Allow the ordinary 160 ms leave and 140 ms fade.
                case 11:
                    test.check(!panel.mapped && !surface.barBridgeHovered, "leaving the bridge closes normally");
                    if (test.side + 1 < test.sides.length) { test.side++; test.step = 0; }
                    else { console.info("WINDOWPEEK_TEST_PASS: bar bridge on all four edges, stationary retention, handoff, inert clicks and leave"); timer.stop(); Qt.quit(); }
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); timer.stop(); Qt.quit(); }
        }
    }
}
