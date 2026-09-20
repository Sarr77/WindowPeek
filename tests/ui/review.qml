import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/I18n.js" as I18n
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int locale: 0
    property int tabs: 0
    property int snapshots: 0
    property int rowTabs: 0
    property real deepestScroll: 0
    property real settingsScroll: 0
    property string imageName: ""
    property var afterImage: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, predicate) {
        if (predicate(item)) return item;
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) {
            var result = find(children[i], predicate); if (result) return result;
        }
        return null;
    }
    function named(name) { return find(panel, function(item) { return item.objectName === name; }); }
    function checkDelayLayout() {
        ["panelHoverDelayControl", "previewHoverDelayControl"].forEach(function(name) {
            var control = named(name);
            var caption = find(control, function(item) { return item.objectName === "delayCaption"; });
            var buttons = find(control, function(item) { return item.objectName === "delayControls"; });
            var a = caption.mapToItem(control, 0, 0), b = buttons.mapToItem(control, 0, 0);
            check(a.x >= 0 && b.x >= 0 && a.x + caption.width <= control.width + 1
                && b.x + buttons.width <= control.width + 1, "delay content fits in " + host.language);
            check(a.x + caption.width <= b.x || b.x + buttons.width <= a.x
                || a.y + caption.height <= b.y || b.y + buttons.height <= a.y,
                "delay label does not overlap controls in " + host.language + ": " + [a.x,a.y,caption.width,caption.height,b.x,b.y,buttons.width,buttons.height].join(","));
        });
    }
    function showSettings() {
        panel.showSettings();
        for (var name of ["settingsPanelSection", "settingsListSection", "settingsPersonalizationSection"])
            named(name).expanded = true;
    }
    function picker() { return find(panel, function(item) { return item.label === host.words.barLabel; }); }
    function screenshot(name, after) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!prefix) { if (after) after(); return; }
        test.snapshots++;
        test.imageName = prefix + "-" + name + ".png";
        test.afterImage = after || null;
        capture.restart();
    }
    function settingsImages(suffix, after) {
        var editor = named("editorScroll");
        editor.contentY = 0;
        screenshot("settings" + suffix, function() {
            panel.ensureVisible(named("settingsListSection"));
            screenshot("settings-list" + suffix, function() {
                panel.ensureVisible(named("settingsPersonalizationSection"));
                screenshot("settings-personalization" + suffix, function() {
                    editor.contentY = 0;
                    if (after) after();
                });
            });
        });
    }
    Timer {
        id: capture; interval: 200
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(test.imageName)) console.error("WINDOWPEEK_TEST_FAIL: image " + test.imageName);
            test.snapshots--;
            if (test.afterImage) test.afterImage();
        })
    }
    TestEvent { id: events }
    FakeHost {
        id: host; updatesAvailable: true
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Window {
        id: window; visible: true
        width: 540 * test.scale; height: 580 * test.scale
        color: Color.popups.background
        Rectangle { anchors.fill: parent; color: Color.popups.background; border.color: host.accent; border.width: 2 }
        Plugin.PanelContent {
            id: panel
            x: 20 * test.scale; y: 20 * test.scale
            width: window.width / test.scale - 40; height: window.height / test.scale - 40
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft; when: panel.QQC.Overlay.overlay !== null }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale; when: panel.QQC.Overlay.overlay !== null }
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (test.snapshots) return;
            try {
                switch (test.step++) {
                case 0:
                    Color.shellValues = {};
                    Color.foreground = "#c0caf5"; Color.background = "#1a1b26"; Color.accent = "#7aa2f7";
                    panel.begin(); break;
                case 1: test.screenshot("windows", function() { test.showSettings(); }); break;
                case 2:
                    host.rejectSave = true;
                    test.picker().open(); break;
                case 3:
                    events.keyClick(Qt.Key_Down, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0); break;
                case 4:
                    test.check(host.saveFailed && host.preference("barLabel", "full") === "full", "failed selection preserves saved label");
                    test.check(test.picker().value === "full", "dropdown cannot confirm an unsaved selection");
                    host.rejectSave = false; host.saveFailed = false;
                    host.persistSettings({barLabel:"name"});
                    test.check(test.picker().value === "name", "picker follows a setting changed by another monitor");
                    host.persistSettings({barLabel:"full"});
                    panel.mode = "appearance"; panel.back();
                    test.check(panel.mode === "settings", "Back from appearance returns to settings");
                    panel.mode = "scaling"; panel.back();
                    test.check(panel.mode === "settings", "Back from scaling returns to settings");
                    panel.mode = "labels"; panel.back();
                    test.check(panel.mode === "settings", "Back from labels returns to settings");
                    break;
                case 5:
                    test.settingsImages("", function() { test.named("updateSwitch").clicked(); }); break;
                case 6: events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 7:
                    test.check(test.named("updateSwitch").activeFocus, "closing confirmation restores its visible control");
                    window.height = 350 * test.scale; test.showSettings(); break;
                case 8: events.keyClick(Qt.Key_Tab, Qt.NoModifier, 0); break;
                case 9:
                    var focused = window.activeFocusItem;
                    test.check(focused && focused.visible, "Tab target is visible");
                    var editor = test.named("editorScroll");
                    var inside = false;
                    for (var parent = focused; parent; parent = parent.parent) if (parent === editor.contentItem) inside = true;
                    if (inside) {
                        var point = focused.mapToItem(editor, 0, 0);
                        test.check(point.y >= -1 && point.y + focused.height <= editor.height + 1,
                            "Tab target stays within the editor viewport: " + focused + " y=" + point.y);
                    }
                    if (++test.tabs < 24) test.step = 8;
                    else { window.width = 370 * test.scale; window.height = 530 * test.scale; }
                    break;
                case 10: host.setLanguage(I18n.languages[test.locale].code); test.showSettings(); break;
                case 11:
                    test.checkDelayLayout();
                    var tools = test.named("footerTools"), credit = test.named("authorCredit");
                    test.check(host.language === "ar" ? credit.x + credit.width <= tools.x : tools.x + tools.width <= credit.x,
                        "footer does not overlap in " + host.language);
                    if (["en", "pl", "de", "ar", "ja"].indexOf(host.language) >= 0) test.settingsImages("-" + host.language);
                    if (++test.locale < I18n.languages.length) test.step = 10;
                    else { host.setLanguage("en"); window.width = 540 * test.scale; window.height = 580 * test.scale; }
                    break;
                case 12:
                    panel.ensureVisible(test.named("openColorsButton"));
                    test.settingsScroll = test.named("editorScroll").contentY;
                    test.named("openColorsButton").clicked(); break;
                case 13: test.screenshot("appearance", function() { panel.back(); }); break;
                case 14:
                    test.check(test.named("openColorsButton").activeFocus, "Back restores the editor entry focus");
                    test.check(Math.abs(test.named("editorScroll").contentY - test.settingsScroll) < 1,
                        "Back preserves the settings scroll position: " + test.settingsScroll + " -> " + test.named("editorScroll").contentY + " saved=" + panel.settingsScrollY + " rowY=" + test.named("openColorsButton").mapToItem(test.named("editorScroll").contentItem,0,0).y + " content=" + test.named("editorScroll").contentHeight + " viewport=" + test.named("editorScroll").height);
                    test.find(panel, function(item) { return item.text === host.words.scaling && item.clicked !== undefined; }).clicked(); break;
                case 15: test.screenshot("scaling", function() { panel.back(); }); break;
                case 16: test.named("openLabelsButton").clicked(); break;
                case 17: test.screenshot("labels", function() { panel.back(); panel.back(); panel.openMove("0x1"); }); break;
                case 18: test.named("destinationPicker").close(); break;
                case 19: test.screenshot("move", function() { panel.back(); }); break;
                case 20: test.named("updateSwitch").clicked(); break;
                case 21: test.screenshot("confirmation"); break;
                case 22:
                    if (test.snapshots) { test.step--; return; }
                    test.named("cancelUpdateOff").clicked();
                    var data = JSON.parse(JSON.stringify(host.snapshot));
                    data.clients = [];
                    for (var i = 1; i <= 40; i++) data.clients.push({address:"0x" + i.toString(16),
                        class:"code", app:"Editor", title:"Fictional document " + i, workspace:{id:1,name:"1"}});
                    host.snapshot = data;
                    window.height = 350 * test.scale; panel.begin(); test.tabs = 0;
                    break;
                case 23: events.keyClick(Qt.Key_Tab, Qt.NoModifier, 0); break;
                case 24:
                    var target = window.activeFocusItem;
                    var list = test.named("windowList");
                    if (target.objectName === "windowFocus" || target.objectName === "windowMove") {
                        test.rowTabs++;
                        var position = target.mapToItem(list, 0, 0);
                        test.check(position.y >= -1 && position.y + target.height <= list.height + 1,
                            "Tab target stays within the window list: y=" + position.y);
                        test.deepestScroll = Math.max(test.deepestScroll, list.contentY);
                    }
                    if (++test.tabs < 32) test.step = 23;
                    break;
                case 25:
                    test.check(test.rowTabs >= 12 && test.deepestScroll > test.named("windowList").height,
                        "keyboard traverses windows beyond the first viewport");
                    window.height = 580 * test.scale;
                    test.showSettings(); break;
                case 26:
                    var toggle = test.named("openOnHoverToggle");
                    panel.ensureVisible(toggle);
                    events.mouseClick(toggle, 15, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(!host.openOnHover && !toggle.checked && toggle.activeFocus,
                        "clicking the switch label saves and focuses the row");
                    host.rejectSave = true;
                    events.keyClick(Qt.Key_Space, Qt.NoModifier, 0);
                    test.check(!toggle.checked && host.saveFailed, "failed keyboard toggle preserves saved switch state");
                    host.rejectSave = false;
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.openOnHover && toggle.checked, "Enter retries the switch save");
                    host.persistSettings({openOnHover: false});
                    test.check(!toggle.checked, "switch follows changes from another monitor");
                    events.mouseClick(toggle, toggle.width - 20, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(toggle.checked && host.openOnHover, "the switch indicator uses the same action as its label");
                    host.setLanguage("ar"); break;
                case 27:
                    test.checkDelayLayout();
                    stop();
                    test.named("editorScroll").contentY = 0;
                    test.screenshot("settings-wide-ar", function() { console.info("WINDOWPEEK_TEST_PASS"); Qt.quit(); });
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
