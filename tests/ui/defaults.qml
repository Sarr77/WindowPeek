import QtQuick
import QtQuick.Window
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
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function named(name) { return find(panel, name); }
    function reset(name) { return find(named(name), "resetDefaultButton"); }
    function click(item) { events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0); }
    function checkLayout(item) {
        if (!item.visible) return;
        if (item.objectName === "resetDefaultButton") {
            var caption = find(item.parent, "defaultCaption");
            var b = item.mapToItem(item.parent, 0, 0);
            check(b.x >= -1 && b.x + item.width <= item.parent.width + 1, "reset fits in " + host.language);
            if (caption) {
                var a = caption.mapToItem(item.parent, 0, 0);
                check(caption.width >= 80 && a.x >= -1 && a.x + caption.width <= item.parent.width + 1,
                    "default value fits in " + host.language);
                check(a.x + caption.width <= b.x || b.x + item.width <= a.x, "reset does not overlap default text in " + host.language);
            }
            check(item.Accessible.name.indexOf(I18n.words(host.language).resetValue) === 0,
                "icon has a translated accessible action name in " + host.language);
        }
        for (var child of item.children || []) checkLayout(child);
    }
    TestEvent { id: events }
    FakeHost { id: host }
    Window {
        id: window; visible: true; width: 520 * test.scale; height: (panel.implicitHeight + 32) * test.scale
        color: Color.popups.background
        Item { id: focusSink; width: 1; height: 1 }
        Plugin.PanelContent {
            id: panel; x: 16 * test.scale; y: 16 * test.scale; width: window.width / test.scale - 32; height: implicitHeight
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
    }
    Timer {
        interval: 90; repeat: true; running: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    host.persistSettings({panelHoverDelay: 0, previewHoverDelay: 1250,
                        hintsMode: "on", hintsUsed: 200, autoUpdates: false, scrollBounce: false});
                    panel.begin(); panel.showSettings(); test.named("settingsPanelSection").expanded = true;
                    break;
                case 1:
                    panel.ensureVisible(test.named("panelHoverDelayControl")); break;
                case 2:
                    var reset = test.reset("panelHoverDelayControl");
                    events.mouseMove(reset, reset.width / 2, reset.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(reset.foreground.toString() === host.accent.toString(), "reset hover uses the current accent");
                    host.rejectSave = true; test.click(test.reset("panelHoverDelayControl"));
                    test.check(host.saveFailed && host.panelHoverDelay === 0 && test.reset("panelHoverDelayControl").enabled,
                        "rejected reset remains unsaved and available for retry");
                    test.check(test.find(test.named("panelHoverDelayControl"), "delayInput").text === "0", "input keeps saved value on failure");
                    host.rejectSave = false; test.click(test.reset("panelHoverDelayControl"));
                    test.check(host.panelHoverDelay === 400 && host.previewHoverDelay === 1250 && !host.saveFailed,
                        "mouse reset retries and changes only the selected delay");
                    test.check(!reset.modified && reset.enabled, "default reset stays hoverable");
                    host.rejectSave = true; test.click(reset);
                    test.check(!host.saveFailed, "clicking an already-default value does not write preferences");
                    host.rejectSave = false;
                    host.previewAppearance({accentColor:"#22CC88"});
                    test.check(reset.foreground.toString() === "#22cc88", "default reset hover follows custom theme colors");
                    host.cancelAppearance();
                    events.mouseMove(focusSink, 0, 0, 0, Qt.NoButton, Qt.NoModifier);
                    focusSink.forceActiveFocus(); break;
                case 3:
                    var reset = test.reset("panelHoverDelayControl");
                    test.check(reset.foreground.a >= 0.69 && reset.foreground.a < 1 && !reset.focusable,
                        "idle default reset stays readable without an extra keyboard stop");
                    test.reset("previewHoverDelayControl").forceActiveFocus();
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.previewHoverDelay === 400 && panel.mode === "settings", "keyboard reset preserves Settings");
                    host.persistSettings({previewHoverDelay: 700, windowPreviews: false});
                    test.check(!test.reset("previewHoverDelayControl").enabled, "dependent controls stay disabled with previews off");
                    host.persistSettings({windowPreviews: true});
                    test.reset("previewHoverDelayControl").clicked();
                    test.check(host.previewHoverDelay === 400 && host.hints.mode === "on" && host.hints.used === 100
                        && host.settings.hintsUsed === 200
                        && host.settings.autoUpdates === false && !host.scrollBounce, "resets preserve unrelated choices and hint history");
                    host.persistSettings({panelHoverDelay: 900});
                    test.check(test.reset("panelHoverDelayControl").enabled, "reset follows a saved change from another view");
                    host.saveAppearance({uiScale: 1.4, barScale: 1.2});
                    test.named("openScalingButton").clicked(); break;
                case 4:
                    test.reset("panelScaleControl").clicked();
                    test.check(host.appearance.uiScale === 1 && host.appearance.barScale === 1.2
                        && host.savedAppearance.uiScale === 1.4, "scale reset changes only the selected draft");
                    panel.back();
                    test.check(host.appearance.uiScale === 1.4, "Back undoes scale reset");
                    test.named("openScalingButton").clicked();
                    test.reset("panelScaleControl").clicked(); test.reset("barScaleControl").clicked();
                    var scaling = test.named("scalingEditor");
                    host.rejectSave = true; scaling.apply();
                    test.check(scaling.saveFailed && host.savedAppearance.uiScale === 1.4 && panel.mode === "scaling", "failed scale Apply retains saved values");
                    host.rejectSave = false; scaling.apply();
                    test.check(host.savedAppearance.uiScale === 1 && host.savedAppearance.barScale === 1, "Apply saves scale defaults");
                    test.named("openScalingButton").clicked();
                    var scaleInput = test.find(test.named("panelScaleControl"), "scaleInput");
                    scaleInput.text = "";
                    test.check(test.reset("panelScaleControl").enabled, "Reset remains available for invalid scale input at the default");
                    test.reset("panelScaleControl").clicked();
                    test.check(scaleInput.text === "100" && test.named("panelScaleControl").valid, "Reset repairs invalid scale input");
                    panel.back();
                    host.saveAppearance({colorScope: "theme", themeColors: {"tokyo-night": {mode:"custom",color:"#FF8800"}, nord:{mode:"custom",color:"#22CC88"}},
                        colorPresets:[{id:"preset-1",name:"Amber",color:"#FF8800"}]});
                    test.named("openColorsButton").clicked(); break;
                case 5:
                    test.reset("colorDefault").clicked();
                    test.check(String(host.accent) === "#d898f5" && String(host.savedAppearance.themeColors["tokyo-night"].color) === "#FF8800",
                        "color reset previews factory color, not saved custom color");
                    var colors = test.named("appearanceEditor");
                    test.check(colors.draft.themeColors.nord.color === "#22CC88" && colors.draft.colorPresets.length === 1, "reset preserves other themes and presets");
                    panel.back(); test.check(String(host.accent) === "#ff8800", "Back undoes color reset");
                    test.named("openColorsButton").clicked(); colors = test.named("appearanceEditor"); test.reset("colorDefault").clicked();
                    host.rejectSave = true; colors.apply();
                    test.check(colors.saveFailed && host.savedAppearance.themeColors["tokyo-night"].mode === "custom", "failed color Apply keeps saved custom color");
                    host.rejectSave = false; colors.apply();
                    test.check(host.savedAppearance.themeColors["tokyo-night"].mode === "adaptive"
                        && host.savedAppearance.colorPresets.length === 1 && host.savedAppearance.themeColors.nord.color === "#22CC88", "Apply saves only intended color change");
                    host.saveAppearance({colorScope:"all", colorMode:"custom", accentColor:"#FF8800"});
                    test.named("openColorsButton").clicked(); colors = test.named("appearanceEditor"); test.reset("colorDefault").clicked();
                    test.check(colors.colorScope === "all" && colors.draft.colorMode === "adaptive", "global color reset respects displayed scope");
                    colors.apply();
                    host.saveLabels({labelStyle:"custom",customLabels:{panelTitle:"Atlas",move:"Send"}});
                    test.named("openLabelsButton").clicked(); break;
                case 6:
                    test.check(test.find(test.named("labelDefault_panelTitle"), "defaultCaption").text === "Default: WindowPeek", "custom text shows its original value while edited");
                    test.reset("labelDefault_panelTitle").clicked();
                    test.check(host.textTemplates.panelTitle === "WindowPeek" && host.words.move === "Send"
                        && host.savedLabels.customLabels.panelTitle === "Atlas", "field reset previews only its translated default");
                    panel.back(); test.check(host.textTemplates.panelTitle === "Atlas", "Back restores custom text");
                    test.named("openLabelsButton").clicked(); test.reset("labelDefault_panelTitle").clicked();
                    var labels = test.named("labelsEditor");
                    host.rejectSave = true; labels.apply();
                    test.check(labels.saveFailed && host.savedLabels.customLabels.panelTitle === "Atlas", "failed label Apply keeps saved custom text");
                    host.rejectSave = false; labels.apply();
                    test.check(!host.savedLabels.customLabels.panelTitle && host.words.move === "Send", "Apply clears only the reset field");
                    panel.showSettings(); test.named("settingsPanelSection").expanded = true;
                    break;
                case 7:
                    window.width = 400 * test.scale;
                    host.setLanguage(I18n.languages[test.locale].code); break;
                case 8:
                    test.checkLayout(panel);
                    test.named("openColorsButton").clicked(); break;
                case 9:
                    test.checkLayout(panel); panel.back(); test.named("openScalingButton").clicked(); break;
                case 10:
                    test.checkLayout(panel); panel.back(); test.named("openLabelsButton").clicked(); break;
                case 11:
                    test.checkLayout(panel); panel.back();
                    if (++test.locale < I18n.languages.length) test.step = 7;
                    else {
                        console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                    }
                    break;
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
