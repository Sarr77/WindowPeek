import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int languageIndex: 0
    property int whiteRed: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function sample(image, x, y, channel) {
        var factor = image.width / window.contentItem.width;
        var point = canvas.mapToItem(window.contentItem, x, y);
        return image[channel](Math.round(point.x * factor), Math.round(point.y * factor));
    }
    FakeHost { id: host }
    TestEvent { id: events }
    TestCase { id: pixels; when: false; name: "GlassPixels" }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: 820 * test.scale
        color: Color.popups.background
        Rectangle {
            id: canvas; x: 20 * test.scale; y: 10 * test.scale
            width: 500; height: 60; color: "white"
            scale: test.scale; transformOrigin: Item.TopLeft
            Plugin.RowSurface {
                id: row; x: 5; y: 5; width: 490; height: 50
                glass: host.glassPanels; accent: host.accent
                Rectangle { x: 25; y: 10; width: 25; height: 25; color: host.accent }
                Text { x: 70; y: 10; text: "Atlas project"; color: Color.popups.text }
            }
        }
        Plugin.PanelContent {
            id: panel; x: 20 * test.scale; y: 90 * test.scale
            width: 500; height: implicitHeight; hostWidget: host
            scale: test.scale; transformOrigin: Item.TopLeft
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale }
        }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            try {
                var picker = test.find(panel, "panelStylePicker");
                switch (test.step++) {
                case 0:
                    Color.shellValues = {}; Color.background = "#1b1b26"; Color.foreground = "#b7bedb";
                    panel.begin(); panel.showSettings();
                    test.find(panel, "settingsPersonalizationSection").expanded = true;
                    test.check(!host.glassPanels && picker.value === "solid", "fixture begins with the legacy solid style");
                    host.persistSettings({panelStyle:"invalid"});
                    test.check(!host.glassPanels && picker.value === "solid", "unknown styles fall back to solid");
                    host.rejectSave = true; picker.changed("glass");
                    test.check(host.saveFailed && !host.glassPanels && picker.value === "solid", "failed save keeps the old style");
                    host.rejectSave = false; picker.changed("glass");
                    test.check(host.glassPanels && picker.value === "glass", "glass selection saves");
                    break;
                case 1:
                    var shot = pixels.grabImage(window.contentItem);
                    test.whiteRed = test.sample(shot, 450, 30, "red");
                    test.check(test.whiteRed > 80 && test.whiteRed < 180, "row darkens a bright backdrop without hiding it");
                    test.check(Math.abs(test.sample(shot, 42, 25, "red") - host.accent.r * 255) < 2,
                        "foreground icon keeps its full color");
                    canvas.color = "#00ddff"; break;
                case 2:
                    var shot = pixels.grabImage(window.contentItem);
                    test.check(test.sample(shot, 450, 30, "red") < test.whiteRed - 70,
                        "row shows changes in the actual backdrop");
                    test.check(Math.abs(test.sample(shot, 42, 25, "red") - host.accent.r * 255) < 2,
                        "backdrop changes do not dim foreground content");
                    Color.background = "#eeeeee"; Color.foreground = "#222222"; host.themeId = "light"; host.themeAccent = "#227799";
                    break;
                case 3:
                    test.check(row.color.r > 0.9 && row.color.a < 1 && String(row.accent) === "#227799",
                        "glass follows light theme background and accent");
                    host.saveAppearance({uiScale:1.25, colorMode:"theme"});
                    test.check(host.glassPanels, "changing colors or scale preserves glass");
                    host.setLanguage(I18n.languages[test.languageIndex++].code); break;
                case 4:
                    test.check(picker.label === host.words.panelBackground && picker.options[2].label === host.words.glassPanel,
                        "background choice follows language " + host.language);
                    if (test.languageIndex < I18n.languages.length) test.step = 3;
                    else {
                        host.setLanguage("en"); panel.ensureVisible(picker); picker.open();
                    }
                    break;
                case 5:
                    test.check(picker.popupOpen, "background picker opens");
                    events.keyClick(Qt.Key_Up, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_Up, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0); break;
                case 6:
                    test.check(!host.glassPanels && picker.value === "solid", "keyboard selects the solid style");
                    picker.changed("glass");
                    var control = test.find(panel, "backgroundTransparencyControl");
                    test.check(control.value === 8 && control.defaultValue === 8, "windows have a subtle default transparency");
                    control.choose(17); test.check(host.glassTransparency === 17, "slider saves window transparency");
                    host.rejectSave = true; control.choose(50);
                    test.check(control.value === 17 && test.find(control, "transparencySlider").value === 17, "failed save restores slider");
                    host.rejectSave = false; picker.changed("wallpaper");
                    test.check(control.value === 70 && control.defaultValue === 70, "wallpaper has its own default");
                    control.choose(63); test.check(host.wallpaperTransparency === 63 && host.glassTransparency === 17, "transparencies stay independent");
                    test.find(control, "resetDefaultButton").clicked();
                    test.check(host.wallpaperTransparency === 70 && host.glassTransparency === 17, "reset changes only the current background");
                    test.find(panel, "wallpaperBlurToggle").clicked();
                    test.find(panel, "backgroundTextureToggle").clicked();
                    test.check(host.backgroundBlur && host.backgroundTexture, "effects are optional and saved separately");
                    test.find(panel,"settingsPanelSection").expanded = true;
                    test.find(panel,"previewBackdropToggle").clicked();
                    test.find(panel,"previewFitToggle").clicked();
                    test.check(!host.previewBackdrop && !host.previewFit,"preview options save independently");
                    console.info("WINDOWPEEK_TEST_PASS: glass preference, theme and painted contrast"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
