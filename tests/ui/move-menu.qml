import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int surface: 0
    property var mainList: null
    property real mainScroll: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function wheel(item, x, y, delta) { events.mouseWheel(item, x, y, Qt.NoButton, Qt.NoModifier, 0, delta, 0); }
    function checkMainStill(message) {
        check(Math.abs(mainList.contentY - mainScroll) < 0.1,
            message + " (" + mainScroll + " -> " + mainList.contentY + ", expanded=" + panel.expanded + ")");
    }
    function checkFooter() {
        var button = find(menu, "moveMenuScratchpad");
        var position = button.mapToItem(menu.card, 0, 0);
        check(Math.abs(position.y + button.height + menu.card.padding - menu.card.height) < 1,
            "Scratchpad stays at the menu's bottom edge");
        check(button.width === menu.card.width - menu.card.padding * 2, "Scratchpad spans the content width");
        check(!menu.filtered.some(w => w.value === "special:scratchpad"), "Scratchpad is not duplicated in the list");
    }
    TestEvent { id: events }
    FakeHost {
        id: host
        Component.onCompleted: {
            savedAppearance = Appearance.normalize({uiScale:test.scale});
            var data = JSON.parse(JSON.stringify(snapshot));
            for (var i = 16; i < 46; i++) data.clients.push({address:"0x" + i.toString(16),
                class:"foot", title:"Fictional window " + i, workspace:{id:1,name:"1"}});
            snapshot = data;
        }
    }
    Window {
        id: window; width: 720 * test.scale; height: 560 * test.scale; visible: true
        color: Color.popups.background
        Plugin.PanelContent {
            id: panel; x: 16; y: 16; width: 420; height: 500
            hostWidget: host; expanded: false; expansion: 0
            scale: test.scale; transformOrigin: Item.TopLeft
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale }
            Plugin.MoveMenu { id: menu; hostWidget: host; parent: window.contentItem }
        }
    }
    Timer {
        interval: 130; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.begin(false); menu.show("0x1", Qt.point(300 * test.scale, 110 * test.scale)); break;
                case 1:
                    test.check(menu.visible && !panel.expanded && panel.mode === "windows", "small menu leaves the overview intact");
                    var point = menu.card.mapToItem(null, 0, 0);
                    test.check(point.x === 300 * test.scale && point.y === 110 * test.scale && menu.card.width <= 280,
                        "menu anchors to the click: " + JSON.stringify({x:point.x,y:point.y,w:menu.card.width,s:menu.uiScale}));
                    test.check(menu.searchField.activeFocus, "menu owns keyboard focus");
                    menu.searchField.hoverEnabled = true;
                    events.mouseMove(menu.searchField, 12, menu.searchField.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(menu.searchField.hovered, "move menu search receives hover");
                    test.check(!menu.destinations.some(w => w.value === "1") && menu.destinations.some(w => w.value === "special:scratchpad"), "source excluded, Scratchpad offered");
                    events.keyClick(Qt.Key_4, Qt.NoModifier, 0); break;
                case 2:
                    test.check(menu.filtered.length === 1 && menu.filtered[0].value === "4", "workspace filtering");
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.moved === "0x1:4", "Enter moves to the chosen workspace");
                    host.moveCompleted(); break;
                case 3:
                    test.check(!menu.visible && !panel.expanded, "completed move closes only the menu");
                    host.moved = "";
                    menu.show("0x1", Qt.point(window.width - 2, window.height - 2)); break;
                case 4:
                    var point = menu.card.mapToItem(null, 0, 0);
                    test.check(point.x >= 8 * test.scale && point.x + menu.card.width * test.scale <= window.width - 8 * test.scale
                        && point.y + menu.card.height * test.scale <= window.height - 8 * test.scale, "menu fits bottom-right screen edge");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 5:
                    test.check(!menu.visible && !host.moved && panel.opened, "Escape cancels without moving or closing the list");
                    menu.show("0x1", Qt.point(20 * test.scale, 20 * test.scale));
                    host.actionBusy = true; menu.select("4");
                    test.check(!host.moved, "busy menu cannot submit a second move");
                    host.actionBusy = false; menu.select("missing");
                    test.check(!host.moved, "unavailable destination refused");
                    host.actionError = "groupLocked"; break;
                case 6:
                    test.check(menu.visible, "action error leaves destinations available for retry");
                    menu.close(); host.actionError = "";
                    menu.show("0x1", Qt.point(300 * test.scale, 110 * test.scale)); break;
                case 7:
                    test.mainList = test.find(panel, "windowList");
                    test.mainList.cancelFlick(); test.mainList.contentY = 120; test.mainScroll = 120;
                    menu.list.cancelFlick(); menu.list.positionViewAtBeginning();
                    test.wheel(menu.list, 20, 40, -120); break;
                case 9:
                    test.check(menu.list.contentY > menu.list.originY, "menu still scrolls normally");
                    test.checkFooter();
                    test.checkMainStill("scrolling menu must not move the window list");
                    menu.list.cancelFlick(); menu.list.positionViewAtEnd();
                    test.wheel(menu.list, 20, 40, -120); break;
                case 11:
                    test.checkMainStill("wheel at the menu's bottom edge must not leak");
                    menu.list.cancelFlick(); menu.list.positionViewAtBeginning();
                    test.wheel(menu.list, 20, 40, 120); break;
                case 13:
                    test.checkMainStill("wheel at the menu's top edge must not leak");
                    menu.searchField.text = "4"; break;
                case 14: test.wheel(menu.list, 20, 16, -120); break;
                case 16:
                    test.checkMainStill("a filtered menu without overflow must consume the wheel");
                    test.checkFooter();
                    test.wheel(menu.card, 20, 20, -120); break;
                case 18:
                    test.checkMainStill("menu heading must consume the wheel");
                    test.wheel(menu.searchField, 20, 10, -120); break;
                case 20:
                    test.checkMainStill("menu search must consume the wheel");
                    test.wheel(menu.card, menu.card.width - 3, 100, -120); break;
                case 22:
                    test.checkMainStill("menu padding must consume the wheel");
                    test.wheel(menu, 120, 260, -120); break;
                case 24:
                    test.checkMainStill("open menu's backdrop must consume the wheel");
                    menu.close(); test.wheel(test.mainList, 40, 100, -120); break;
                case 27:
                    test.check(test.mainList.contentY > test.mainScroll, "window list scrolls again after closing menu");
                    menu.searchField.text = "";
                    menu.show("0x1", Qt.point(300 * test.scale, 110 * test.scale));
                    if (test.surface++ === 0) {
                        panel.expanded = true; panel.expansion = 1; test.step = 7; break;
                    }
                    break;
                case 28:
                    menu.searchField.text = "no matching workspace"; break;
                case 29:
                    test.checkFooter();
                    var button = test.find(menu, "moveMenuScratchpad");
                    test.check(button.enabled && menu.filtered.length === 0, "Scratchpad stays available independently of the filter");
                    test.wheel(button, 20, button.height / 2, -120);
                    host.actionBusy = true;
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(!host.moved, "busy Scratchpad button cannot dispatch");
                    host.actionBusy = false; break;
                case 30:
                    var button = test.find(menu, "moveMenuScratchpad");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(host.moved === "0x1:special:scratchpad", "pinned button moves the selected window to Scratchpad");
                    host.moveCompleted(); menu.show("0x5", Qt.point(300 * test.scale, 110 * test.scale)); break;
                case 31:
                    test.check(!test.find(menu, "moveMenuScratchpad").enabled, "already in Scratchpad disables the shortcut");
                    host.moved = "";
                    menu.show("0x1", Qt.point(300 * test.scale, 110 * test.scale)); break;
                case 32:
                    var button = test.find(menu, "moveMenuScratchpad");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton, Qt.NoModifier, 0);
                    test.check(!menu.opened && !host.moved && panel.mode === "windows",
                        "right-click over the footer closes only the menu without moving the window");
                    menu.show("0x1", Qt.point(300 * test.scale, 110 * test.scale)); break;
                case 33:
                    console.info("WINDOWPEEK_TEST_PASS"); stop();
                    var path = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (path) window.contentItem.grabToImage(function(result) { result.saveToFile(path); Qt.quit(); });
                    else Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
