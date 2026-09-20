import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int locale: 0
    property int focusWaits: 0
    property int reopenCycles: 0
    property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property var body: null
    property var surface: null
    property var list: null
    property var pointer: null
    property int revision: 0
    property real wheelStart: 0
    property var actualCursor: ({})
    function check(value, message) { if (!value) throw new Error(message); }
    function movePointer(item, x, y) {
        var position = item.mapToGlobal(x, y);
        pointerMover.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x="
            + Math.round(position.x) + ",y=" + Math.round(position.y) + "}))"];
        pointerMover.running = true;
    }
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
    TestEvent { id: events }
    Process {
        id: pointerMover
        property bool failed: false
        onExited: function(code) { failed = code !== 0; }
    }
    Process {
        id: pointerProbe
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector { onStreamFinished: test.actualCursor = JSON.parse(text) }
    }
    FakeHost {
        id: host
        bar: barApi
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale: test.scale})
    }
    Ui.PluginBarApi {
        id: barApi
        pluginId: "sarr.windowpeek.test"; moduleName: plugin.moduleName
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
    Timer {
        interval: 35; repeat: true; running: test.step >= 9
        onTriggered: {
            var data = JSON.parse(JSON.stringify(host.snapshot));
            data.clients[0].title = "Fictional progress " + (++test.revision);
            host.snapshot = data;
        }
    }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    test.body = test.find(plugin, "windowPeekContent", []);
                    test.surface = test.find(plugin, "windowPeekPanel", []);
                    test.check(test.body && test.surface, "native panel loaded");
                    plugin.open(); break;
                case 1:
                    if (!test.body.searchField.activeFocus && test.focusWaits++ < 10) { test.step--; break; }
                    test.check(plugin.opened && test.body.searchField.activeFocus, "native opening focuses search");
                    test.check(test.surface.focusPrimed, "native panel releases exclusive focus after priming");
                    test.check(test.surface.cardOrigin.y + test.surface.contentHeight <= test.surface.screenH, "scaled card fits screen height");
                    test.check(test.surface.cardOrigin.x + test.surface.contentWidth <= test.surface.screenW, "scaled card fits screen width");
                    events.keyClick(Qt.Key_P, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_R, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_O, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_J, Qt.NoModifier, 0);
                    break;
                case 2:
                    test.check(test.body.matches.length === 2, "native keyboard reaches search");
                    events.keyClick(Qt.Key_Down, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.focused === "0x2", "native Enter uses selected address: " + JSON.stringify({selected:test.body.selectedAddress, focused:host.focused, searchFocus:test.body.searchField.activeFocus}));
                    var focus = test.find(test.body, "windowFocus", []);
                    var move = test.find(test.body, "windowMove", []);
                    events.mouseClick(focus, focus.width / 2, focus.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(host.focused === "0x1", "row click focuses its own address");
                    host.focused = "";
                    events.mouseClick(move, move.width / 2, move.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(host.focused === "", "Move does not activate the focus control");
                    break;
                case 3:
                    test.check(test.body.mode === "move" && test.body.moveAddress === "0x1", "Move opens the exact row's destination picker");
                    test.body.back(); test.body.showSettings(); break;
                case 4:
                    test.find(test.body, "languages", []).open(); break;
                case 5:
                    var languages = test.find(test.body, "languages", []);
                    test.check(languages.popupOpen && languages.placement.height > 0, "scaled language picker opens");
                    languages.close(); test.body.back();
                    break;
                case 6:
                    host.setLanguage(I18n.languages[test.locale++].code);
                    break;
                case 7:
                    var tools = test.find(test.body, "footerTools", []);
                    var credit = test.find(test.body, "authorCredit", []);
                    test.check(host.language === "ar" ? credit.x + credit.width <= tools.x : tools.x + tools.width <= credit.x,
                        "footer controls do not overlap: " + host.language);
                    if (test.locale < I18n.languages.length) test.step = 6;
                    else { host.setLanguage("pl"); test.body.searchField.text = ""; }
                    break;
                case 8:
                    var icon = test.find(test.body, "windowIcon", []);
                    if (DesktopEntries.byId("code")) test.check(icon.entry && icon.status === Image.Ready, "desktop icon resolves after application index loads");
                    var image = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (image) test.body.parent.parent.grabToImage(function(result) { result.saveToFile(image); });
                    var many = JSON.parse(JSON.stringify(host.snapshot));
                    for (var i = 6; i <= 25; i++) many.clients.push({address:"0x" + i.toString(16), class:"code", app:"Editor",
                        title:"Fictional document " + i, workspace:{id:1,name:"1"}});
                    host.snapshot = many;
                    test.list = test.find(test.body, "windowList", []);
                    break;
                case 9:
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                    test.check(!plugin.opened, "native Escape closes panel");
                    plugin.open(); plugin.close(); plugin.open();
                    test.focusWaits = 0;
                    break;
                case 10:
                    var ready = plugin.opened && !plugin.opening && test.surface.backingWindowVisible
                        && test.surface.focusPrimed && test.body.searchField.activeFocus;
                    if (!ready && test.focusWaits++ < 10) { test.step--; break; }
                    test.check(ready, "rapid reopen restores keyboard focus: " + JSON.stringify({
                        opened: plugin.opened, visible: test.surface.backingWindowVisible, primed: test.surface.focusPrimed,
                        windowActive: test.body.Window.window.active, searchFocus: test.body.searchField.focus,
                        mode: test.body.mode, focusedItem: test.body.Window.window.activeFocusItem ? test.body.Window.window.activeFocusItem.objectName : "none"
                    }));
                    test.check(test.list.atYBeginning, "reopened panel starts at the first row");
                    test.pointer = test.find(test.list.itemAtIndex(1), "windowFocusPointer", []);
                    test.check(test.pointer, "first window control loaded after reopen");
                    // QtTest motion doesn't move the compositor's pointer. After
                    // remapping, a native enter can overwrite that synthetic hover.
                    test.movePointer(test.body.searchField, 10, 10);
                    break;
                case 11:
                    test.check(!pointerMover.running && !pointerMover.failed, "native pointer move completes");
                    test.movePointer(test.pointer, 40, 20);
                    break;
                case 12:
                    pointerProbe.running = true;
                    events.mouseMove(test.pointer, 40, 20, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(test.pointer.containsMouse, "pointer enters first window control after reopen");
                    break;
                case 13:
                    test.check(test.pointer === test.find(test.list.itemAtIndex(1), "windowFocusPointer", [])
                        && test.pointer.containsMouse, "reopened panel keeps the hovered control during refresh: " + JSON.stringify({
                            cycle:test.reopenCycles, same:test.pointer === test.find(test.list.itemAtIndex(1), "windowFocusPointer", []),
                            hovered:test.pointer ? test.pointer.containsMouse : false, focus:test.body.searchField.activeFocus,
                            scroll:test.list.contentY, origin:test.list.originY, cursor:test.actualCursor,
                            target:test.pointer.mapToGlobal(40,20), mouse:[test.pointer.mouseX,test.pointer.mouseY]}));
                    test.wheelStart = test.list.contentY;
                    var point = test.pointer.mapToItem(test.list, 40, 20);
                    events.mouseWheel(test.list, point.x, point.y, Qt.NoButton, Qt.NoModifier, 0, -240, 0);
                    break;
                case 14:
                    test.check(test.list.contentY > test.wheelStart, "wheel scrolls after reopen while titles update");
                    test.check(test.body.searchField.activeFocus, "wheel and visible hints preserve search focus");
                    if (++test.reopenCycles < 8) { test.step = 9; break; }
                    plugin.close();
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { plugin.close(); console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
