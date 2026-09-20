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
    property bool capturing: false
    property string imageName: ""
    property string savedSettings: ""
    property int localeIndex: 0
    property real previousScroll: 0
    property real headerY: 0
    property real settingsHeight: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function named(name) { return find(panel, name); }
    function section(name) { return named("settings" + name + "Section"); }
    function textItems(item) {
        var result = item.text !== undefined ? [item] : [];
        for (var child of item.children || []) result = result.concat(textItems(child));
        return result;
    }
    function click(item) { events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0); }
    function image(name) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!prefix) return;
        capturing = true; imageName = prefix + "-" + name + ".png"; capture.restart();
    }
    Timer {
        id: capture; interval: 160
        onTriggered: window.contentItem.grabToImage(function(result) {
            test.check(result.saveToFile(test.imageName), "image saved"); test.capturing = false;
        })
    }
    TestEvent { id: events }
    FakeHost {
        id: host
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: (panel.implicitHeight + 40) * test.scale
        color: Color.popups.background
        Rectangle { anchors.fill: parent; color: Color.popups.background; border.width: 1; border.color: host.accent }
        Plugin.PanelContent {
            id: panel
            x: 20 * test.scale; y: 20 * test.scale; width: 500; height: implicitHeight
            hostWidget: host; scale: test.scale; transformOrigin: Item.TopLeft
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale }
        }
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            if (test.capturing) return;
            try {
                switch (test.step++) {
                case 0:
                    Color.shellValues = {}; Color.foreground = "#c0caf5"; Color.background = "#1a1b26"; Color.accent = "#7aa2f7";
                    panel.begin(); panel.showSettings(); test.savedSettings = JSON.stringify(host.settings); break;
                case 1:
                    test.check(!test.section("Panel").expanded && !test.section("List").expanded && !test.section("Personalization").expanded && !test.section("Controls").expanded,
                        "settings opens as a compact category overview");
                    test.check(!test.named("openOnHoverToggle").visible && panel.implicitHeight >= 600, "collapsed controls are hidden in a spacious settings panel");
                    test.settingsHeight = panel.implicitHeight;
                    test.image("overview"); break;
                case 2:
                    test.headerY = test.section("Panel").headerItem.mapToItem(window.contentItem, 0, 0).y;
                    test.click(test.section("Panel").headerItem); break;
                case 3:
                    test.check(test.named("openOnHoverToggle").visible && test.section("Panel").headerItem.activeFocus, "header expands and owns focus");
                    test.check(JSON.stringify(host.settings) === test.savedSettings, "category expansion does not write preferences");
                    test.check(panel.implicitHeight === test.settingsHeight
                        && Math.abs(test.section("Panel").headerItem.mapToItem(window.contentItem, 0, 0).y - test.headerY) < 1,
                        "expansion keeps the panel size and clicked header stationary");
                    var toggle = test.named("windowPreviewsToggle");
                    var track = test.find(toggle, "settingsSwitchTrack");
                    test.check(track.color.toString() === host.accent.toString(), "enabled switch uses the resolved Colors accent");
                    test.image("panel"); break;
                case 4:
                    host.previewAppearance({accentColor: "#22cc88"});
                    var track = test.find(test.named("windowPreviewsToggle"), "settingsSwitchTrack");
                    test.check(track.color.toString() === "#22cc88", "switch follows a live accent change");
                    host.cancelAppearance();
                    test.click(test.section("Panel").headerItem); break;
                case 5: test.click(test.section("List").headerItem); break;
                case 6: test.image("list"); break;
                case 7: test.named("listDensityPicker").open(); break;
                case 8: test.click(test.section("List").headerItem); break;
                case 9:
                    test.check(!test.section("List").expanded && !test.named("listDensityPicker").popupOpen,
                        "collapsing a category closes its open picker");
                    events.keyClick(Qt.Key_Tab, Qt.NoModifier, 0);
                    test.check(test.section("Personalization").headerItem.activeFocus, "Tab skips controls inside a collapsed category");
                    events.keyClick(Qt.Key_Space, Qt.NoModifier, 0); break;
                case 10:
                    test.check(test.section("Personalization").expanded, "Space opens the focused category");
                    test.image("personalization"); break;
                case 11:
                    panel.ensureVisible(test.named("openColorsButton"));
                    test.click(test.named("openColorsButton")); break;
                case 12:
                    test.check(panel.mode === "appearance", "editor remains accessible inside the category");
                    panel.back(); break;
                case 13:
                    test.check(panel.mode === "settings" && test.section("Personalization").expanded && test.named("openColorsButton").activeFocus,
                        "Back preserves the expanded category and restores the editor control");
                    test.section("Personalization").headerItem.forceActiveFocus();
                    events.keyClick(Qt.Key_Left, Qt.NoModifier, 0);
                    test.check(!test.section("Personalization").expanded, "Left collapses the category");
                    events.mouseClick(test.section("Personalization").headerItem, 20, 20, Qt.RightButton, Qt.NoModifier, 0);
                    test.check(panel.mode === "windows", "right-click Back works on a category header");
                    panel.showSettings(); host.setLanguage("pl"); break;
                case 14: test.image("overview-pl"); break;
                case 15:
                    host.setLanguage("ar"); test.section("Personalization").headerItem.forceActiveFocus();
                    events.keyClick(Qt.Key_Left, Qt.NoModifier, 0); break;
                case 16:
                    test.check(test.section("Personalization").expanded, "Left expands with RTL navigation");
                    test.image("personalization-ar"); break;
                case 17:
                    host.setLanguage("en"); test.section("Personalization").expanded = false;
                    break;
                case 18:
                    panel.ensureVisible(test.section("Controls").headerItem);
                    test.headerY = test.section("Controls").headerItem.mapToItem(window.contentItem, 0, 0).y;
                    test.click(test.section("Controls").headerItem); break;
                case 19:
                    test.check(test.section("Controls").expanded && test.named("controlsHelp").visible, "Controls opens its guide");
                    test.check(panel.implicitHeight === test.settingsHeight
                        && Math.abs(test.section("Controls").headerItem.mapToItem(window.contentItem, 0, 0).y - test.headerY) < 1,
                        "even a long guide expands below its stationary header: before=" + test.headerY
                        + " after=" + test.section("Controls").headerItem.mapToItem(window.contentItem, 0, 0).y
                        + " scroll=" + test.named("editorScroll").contentY + " focus=" + window.activeFocusItem.objectName);
                    test.savedSettings = JSON.stringify(host.settings);
                    test.previousScroll = test.named("editorScroll").contentY;
                    test.image("controls"); break;
                case 20:
                    events.mouseWheel(test.named("editorScroll"), 100, 200, Qt.NoButton, Qt.NoModifier, 0, -120, 0); break;
                case 21:
                    test.check(test.named("editorScroll").contentY > test.previousScroll, "wheel scrolls the Controls guide");
                    var entries = test.textItems(test.named("controlsHelp"));
                    panel.ensureVisible(entries[entries.length - 1]); break;
                case 22:
                    var entries = test.textItems(test.named("controlsHelp"));
                    var last = entries[entries.length - 1];
                    var viewport = test.named("editorScroll");
                    var position = last.mapToItem(viewport, 0, 0);
                    test.check(position.y >= -1 && position.y + last.height <= viewport.height + 1, "last keyboard instruction is reachable");
                    test.check(JSON.stringify(host.settings) === test.savedSettings, "guide browsing does not write preferences");
                    test.image("controls-end"); break;
                case 23:
                    host.setLanguage(I18n.languages[test.localeIndex].code); break;
                case 24:
                    test.check(test.textItems(test.named("controlsHelp")).every(function(item) {
                        return item.text.length && item.height > 0 && item.contentWidth <= item.width + 1 && item.contentHeight <= item.height + 1;
                    }), "all guide instructions wrap without clipping in " + host.language);
                    if (++test.localeIndex < I18n.languages.length) test.step = 23;
                    else { host.setLanguage("pl"); panel.ensureVisible(test.section("Controls").headerItem); }
                    break;
                case 25: test.image("controls-pl"); break;
                case 26:
                    host.setLanguage("ar"); panel.ensureVisible(test.section("Controls").headerItem); break;
                case 27: test.image("controls-ar"); break;
                case 28:
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
