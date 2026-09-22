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
    property int escapes: 0
    property int waits: 0
    property real scrollPosition: 0
    property var list: null
    property var scroll: null
    property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var card: tip.body
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name, address) {
        if (item.objectName === name && (!address || (item.parent.parent.window && item.parent.parent.window.address === address))) return item;
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) {
            var found = find(children[i], name, address);
            if (found) return found;
        }
        return null;
    }
    TestEvent { id: events }
    FakeHost {
        id: host; bar: barApi; includeSpecial: false
        function focusWindow(address) { focused = address; tip.close(); return true; }
        settings: ({hintsMode: "auto", hintsUsed: 99})
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale: test.scale})
    }
    Ui.PluginBarApi {
        id: barApi; pluginId: "sarr.windowpeek.hover.test"
        position: "top"; barSize: 28
    }
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item { id: anchor; x: 100; width: 130; height: 28 }
    }
    // A separate application surface must keep receiving input while the preview is open.
    Window {
        id: focusProbe
        visible: true; width: 200; height: 100
        title: "WindowPeek fictional hover test"
        color: "#191923"
        Item { id: keyTarget; anchors.fill: parent; focus: true; Keys.onEscapePressed: test.escapes++ }
    }
    Plugin.Panel { id: tip; anchorItem: anchor; hostWidget: host; bar: barApi }
    Timer {
        interval: 360; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    if (!keyTarget.activeFocus && test.waits++ < 10) { test.step--; break; }
                    test.check(keyTarget.activeFocus, "focus probe receives keyboard focus");
                    tip.hoverRequested = true; break;
                case 1:
                    test.check(tip.mapped && test.card.preview.count === 4, "native preview shows real QML rows");
                    test.check(host.hints.used === 100 && test.card.showHint, "100th help footer stays readable");
                    test.check(keyTarget.activeFocus, "opening preview does not steal focus");
                    test.check(tip.surface.contentHeight + bar.height + 28 <= bar.screen.height, "scaled native preview fits screen");
                    events.mouseMove(test.card, 30, 50, 0, Qt.NoButton, Qt.NoModifier);
                    tip.hoverRequested = false; break;
                case 2:
                    test.check(tip.mapped, "preview stays open while pointer is over its content");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                    test.check(test.escapes === 1, "preview does not consume keyboard input");
                    events.mouseMove(tip.surface.cardItem, -20, -20, 0, Qt.NoButton, Qt.NoModifier); break;
                case 3:
                    test.check(!tip.mapped, "preview closes after pointer leaves");
                    tip.hoverRequested = true; break;
                case 4:
                    test.check(tip.mapped && !test.card.showHint && host.hints.used === 100,
                        "windows remain available after the automatic help budget expires");
                    host.persistSettings({includeSpecial:true}); break;
                case 5:
                    test.check(test.card.preview.count === 5, "visible preview follows special workspace preference");
                    host.persistSettings({hintsMode:"on"}); break;
                case 6:
                    test.check(test.card.showHint, "manual help on updates current preview");
                    host.persistSettings({hintsMode:"off"}); break;
                case 7:
                    test.check(!test.card.showHint && tip.mapped, "manual help off keeps windows visible");
                    tip.open(); break;
                case 8:
                    test.check(tip.mapped && tip.opened, "opening search promotes the existing surface");
                    tip.close(); tip.hoverRequested = false; break;
                case 9: tip.hoverRequested = true; break;
                case 10:
                    test.check(tip.mapped, "preview can reopen after search closes");
                    barApi.activePopout = focusProbe; break;
                case 11:
                    test.check(!tip.mapped, "another bar popup dismisses preview");
                    barApi.activePopout = null; tip.hoverRequested = false;
                    var many = JSON.parse(JSON.stringify(host.snapshot));
                    for (var i = 6; i <= 35; i++) many.clients.push({address:"0x" + i.toString(16), class:"code", app:"Editor",
                        title:"Fictional document " + i, workspace:{id:i % 4 + 1, name:String(i % 4 + 1)}});
                    host.snapshot = many;
                    test.list = test.find(test.card, "windowList");
                    test.scroll = test.find(test.card, "windowScrollbar");
                    break;
                case 12: tip.hoverRequested = true; break;
                case 13:
                    test.check(test.card.preview.count === 35 && test.card.preview.sections.length === 6, "hover includes every window and workspace");
                    test.check(test.scroll.visible && test.list.contentHeight > test.list.height, "long list has a scrollbar");
                    events.mouseMove(test.list, 30, 50, 0, Qt.NoButton, Qt.NoModifier);
                    tip.hoverRequested = false;
                    events.mouseWheel(test.list, 30, 50, Qt.NoButton, Qt.NoModifier, 0, -240, 0); break;
                case 14:
                    test.check(test.list.contentY > 0, "mouse wheel scrolls the hover list");
                    test.scrollPosition = test.list.contentY;
                    events.mousePress(test.scroll, test.scroll.width / 2,
                        (test.scroll.visualPosition + test.scroll.visualSize / 2) * test.scroll.height, Qt.LeftButton, Qt.NoModifier, 0);
                    events.mouseMove(test.scroll, test.scroll.width / 2, test.scroll.height + 20, 0, Qt.LeftButton, Qt.NoModifier); break;
                case 15:
                    test.check(tip.mapped && test.card.interacting, "dragging beyond scrollbar keeps hover open");
                    test.check(test.list.contentY > test.scrollPosition && test.list.atYEnd, "dragging scrollbar reaches the last window");
                    events.mouseRelease(test.scroll, test.scroll.width / 2, test.scroll.height + 20, Qt.LeftButton, Qt.NoModifier, 0);
                    events.mouseMove(test.list, 30, test.list.height - 10, 0, Qt.NoButton, Qt.NoModifier);
                    test.scrollPosition = test.list.contentY;
                    var refreshed = JSON.parse(JSON.stringify(host.snapshot));
                    refreshed.clients[0].title = "Updated fictional title";
                    host.snapshot = refreshed; break;
                case 16:
                    test.check(Math.abs(test.list.contentY - test.scrollPosition) < 1, "inventory refresh keeps scroll position");
                    test.check(keyTarget.activeFocus, "scrolling does not steal keyboard focus: " + JSON.stringify({
                        probe:focusProbe.active, popup:test.card.Window.window.active, bar:anchor.Window.window.active}));
                    var target = test.find(test.card, "windowFocusPointer", "0x5");
                    test.check(target && target.mapToItem(test.list, 0, 0).y >= 0, "last window is visible after scrolling");
                    events.mouseClick(target, target.width / 2, target.height / 2, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 17:
                    test.check(host.focused === "0x5", "clicking a scrolled row selects its exact address");
                    test.check(!tip.mapped, "accepted click dismisses hover");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
