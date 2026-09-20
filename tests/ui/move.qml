import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int locale: 0
    property real expandedHeight: 0
    property var original: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) { var result = find(item.children[i], name); if (result) return result; }
        return null;
    }
    function button() { return find(panel, "moveToScratchpad"); }
    TestEvent { id: events }
    FakeHost { id: host; Component.onCompleted: savedAppearance = Appearance.normalize({uiScale: test.scale}) }
    Window {
        id: window; visible: true
        width: 540 * test.scale; height: (panel.implicitHeight + 40) * test.scale
        color: Color.popups.background
        Plugin.PanelContent {
            id: panel; x: 20 * test.scale; y: 20 * test.scale
            width: 500; height: implicitHeight; scale: test.scale; transformOrigin: Item.TopLeft
            hostWidget: host
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft; when: panel.QQC.Overlay.overlay !== null }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale; when: panel.QQC.Overlay.overlay !== null }
        }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            try {
                var picker = test.find(panel, "destinationPicker");
                switch (test.step++) {
                case 0:
                    test.original = JSON.parse(JSON.stringify(host.snapshot));
                    panel.opened = true; panel.openMove("0x1"); break;
                case 1:
                    test.check(picker.popupOpen && test.button().enabled, "scratchpad shortcut is in the main move form");
                    test.check(test.button().mapToItem(panel, 0, test.button().height).y <= picker.mapToItem(panel, 0, 0).y,
                        "scratchpad shortcut is above the destination dropdown");
                    test.check(!test.find(panel, "windowScrollbar").visible, "hidden window list leaves no scrollbar in the move form");
                    test.check(test.find(panel, "moveSource").text === "From: Workspace 1 · TEST-A", "source includes workspace and monitor");
                    test.expandedHeight = panel.implicitHeight;
                    events.keyClick(Qt.Key_Z, Qt.NoModifier, 0); break;
                case 2:
                    test.check(picker.filtered.length === 0 && test.button().visible, "main form shortcut remains available while filtering");
                    var button = test.button();
                    var point = button.mapToItem(window.contentItem, 0, 0);
                    test.check(point.y >= 0 && point.y + button.height * test.scale <= window.height, "shortcut fits the scaled window");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(host.moved === "0x1:special:scratchpad" && !host.focused && !picker.popupOpen,
                        "shortcut clicks the selected window's silent move and closes the picker");
                    break;
                case 3:
                    test.check(panel.implicitHeight < test.expandedHeight - 100, "closed picker releases unused panel space");
                    test.check(test.button().visible, "main form shortcut stays visible after the dropdown closes");
                    host.actionBusy = true; picker.open(); break;
                case 4:
                    test.check(!test.button().enabled, "shortcut rejects a concurrent action");
                    host.actionBusy = false; panel.back(); panel.openMove("0x5"); break;
                case 5:
                    test.check(!test.button().enabled, "window already in scratchpad cannot be moved there again");
                    test.check(test.find(panel, "moveSource").text === "From: Scratchpad", "special source uses its display label");
                    panel.back(); host.includeSpecial = false; panel.openMove("0x1"); break;
                case 6:
                    test.check(test.button().enabled, "hiding special inventory does not disable the explicit shortcut");
                    var gone = JSON.parse(JSON.stringify(host.snapshot)); gone.clients = []; host.snapshot = gone; break;
                case 7:
                    test.check(!test.button().enabled, "closed source cannot be retargeted by the shortcut");
                    panel.back(); host.snapshot = test.original; host.includeSpecial = true; panel.openMove("0x1"); break;
                case 8: host.setLanguage(I18n.languages[test.locale++].code); break;
                case 9:
                    var target = test.button();
                    var top = target.mapToItem(window.contentItem, 0, 0);
                    test.check(target.width > 0 && top.y + target.height * test.scale <= window.height,
                        "localized shortcut fits in " + host.language);
                    if (test.locale < I18n.languages.length) test.step = 8;
                    else host.setLanguage("en");
                    break;
                case 10:
                    console.info("WINDOWPEEK_TEST_PASS"); stop();
                    var image = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (image) window.contentItem.grabToImage(function(result) { result.saveToFile(image); Qt.quit(); });
                    else Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
