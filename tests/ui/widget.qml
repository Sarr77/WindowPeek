import QtQuick
import QtQuick.Window
import Quickshell
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    function check(value, message) { if (!value) throw new Error(message); }
    QtObject {
        id: shell
        property var saved: ({})
        property bool rejectSave: false
        function updateEntryInline(id, values) { if (rejectSave) return false; saved = values; return true; }
    }
    Ui.PluginBarApi {
        id: bar
        pluginId: "sarr.windowpeek"; moduleName: "sarr.windowpeek"
        shell: shell
        position: "top"; barSize: 26; fontFamily: "monospace"
        layoutConfig: ({ left: [{ id: "sarr.windowpeek", language: "pl" }], center: [], right: [] })
        _moduleWidgets: function() { return [a, b]; }
    }
    Component { id: transientWidget; Plugin.Widget {} }
    Window {
        id: window
        visible: true; width: 400; height: 60
        Plugin.Widget { id: a; bar: bar }
        Plugin.Widget { id: b; bar: bar; x: 200 }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!a.settingsReady || !b.settingsReady) return;
            try {
                if (test.step === 1) {
                    test.check(a.uiScale === a.savedAppearance.uiScale && b.uiScale === b.savedAppearance.uiScale,
                        "destroying the editor's widget releases its shared preview");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); return;
                }
                test.check(a.language === "pl" && b.language === "pl", "startup restores both monitors");
                test.check(a.includeSpecial && b.includeSpecial, "special workspaces are included by default");
                test.check(a.panelStyle === "wallpaper" && b.panelStyle === "wallpaper"
                    && a.backgroundTexture && b.backgroundTexture && !a.backgroundBlur,
                    "fresh widgets default to Wallpaper with grain and no blur");
                test.check(a.wallpaperTransparency === 70 && !a.wallpaperTransparencyRule.initialized
                    && a.hints.mode === "auto" && a.hints.used === 0 && a.hints.remaining === 200 && a.hints.enabled,
                    "fresh defaults leave theme assessment pending and start the full 200-display hint budget");
                test.check(a.persistSettings({panelStyle:"glass"}) && a.glassPanels && b.glassPanels,
                    "glass setting synchronizes across monitors");
                test.check(b.persistSettings({panelStyle:"solid",backgroundTexture:false}) && !a.glassPanels && !b.glassPanels
                    && !a.backgroundTexture && !b.backgroundTexture,
                    "explicit Solid and disabled grain still override the new defaults on both monitors");
                test.check(a.panelHoverDelay === 400 && a.previewHoverDelay === 400 && a.popupAnimations && a.openOnHover,
                    "existing behavior is the default");
                test.check(a.persistSettings({panelHoverDelay:0, previewHoverDelay:1250, popupAnimations:false, openOnHover:false}), "timing preferences save");
                test.check(b.panelHoverDelay === 0 && b.previewHoverDelay === 1250 && !b.popupAnimations && !b.openOnHover,
                    "timing preferences synchronize across monitors");
                test.check(a.runtime.preferences.values.panelHoverDelay === 0 && a.runtime.preferences.values.popupAnimations === false && !a.runtime.preferences.values.openOnHover,
                    "zero and disabled animations are durable");
                test.check(a.windowPreviews && b.windowPreviews, "window previews default on");
                test.check(a.persistSettings({windowPreviews:false}) && !a.windowPreviews && !b.windowPreviews,
                    "disabling window previews synchronizes monitors");
                test.check(a.runtime.preferences.values.windowPreviews === false, "disabled previews are saved");
                test.check(b.persistSettings({windowPreviews:true}) && a.windowPreviews && b.windowPreviews,
                    "either monitor can restore window previews");
                test.check(a.scrollBounce && b.scrollBounce, "springy scrolling defaults on");
                test.check(a.persistSettings({ scrollBounce: true }) && a.scrollBounce && b.scrollBounce,
                    "enabling springy scrolling updates both monitors");
                test.check(a.persistSettings({ scrollBounce: false }) && !a.scrollBounce && !b.scrollBounce,
                    "disabling springy scrolling updates both monitors");
                test.check(a.persistSettings({ hintsMode: "auto", hintsUsed: 198 }), "save hint budget");
                test.check(a.recordHintShown() && b.recordHintShown(), "shared hint budget across monitors");
                test.check(a.hints.used === 200 && b.hints.used === 200 && !a.hints.enabled, "budget exhausted exactly once");
                test.check(!b.recordHintShown(), "no 201st automatic hint");
                test.check(a.toggleHints() && b.hints.enabled, "manual hints override budget");
                test.check(a.runtime.preferences.values.hintsMode === "on", "manual on is durable");
                for (var hover = 0; hover < 250; hover++) {
                    test.check(!b.recordHintShown() && b.hints.enabled, "manual hints remain enabled beyond the automatic limit");
                }
                test.check(b.toggleHints() && !a.hints.enabled && a.runtime.preferences.values.hintsMode === "off",
                    "manual off is shared and durable");
                test.check(a.toggleHints() && b.hints.enabled, "manual hints can be enabled again without resetting the used count");
                test.check(a.persistSettings({ includeSpecial: false }) && !a.includeSpecial && !b.includeSpecial,
                    "explicit exclusion overrides the new default on both monitors");
                test.check(a.persistSettings({ includeSpecial: true }), "special preference saved");
                test.check(b.includeSpecial && shell.saved.hintsUsed === 200, "rapid saves preserve other values");
                test.check(a.runtime.preferences.values.language === "pl", "durable preferences keep language");
                test.check(a.runtime.preferences.values.scrollBounce === false, "scroll preference survives other settings changes");
                test.check(a.updatesAvailable && !a.runtime.updates.runtimeAvailable, "isolated UI tests cannot start the updater");
                a.previewAppearance({uiScale:1.25});
                test.check(a.uiScale === 1.25 && b.uiScale === 1.25,
                    "appearance preview works even while monitor identity is unavailable");
                b.cancelAppearance();
                test.check(a.uiScale === 1.25, "another widget cannot cancel the appearance editor's preview");
                a.cancelAppearance();
                test.check(a.uiScale === a.savedAppearance.uiScale && b.uiScale === b.savedAppearance.uiScale,
                    "cancel restores saved appearance on both widgets");
                var custom = {labelStyle:"custom", customLabels:{move:"Wyślij", barText:"Okna {count}"}};
                a.previewLabels(custom);
                test.check(a.words.move === "Wyślij" && b.words.move === "Wyślij", "label preview is shared between widget instances");
                test.check(!a.runtime.preferences.values.customLabels, "label preview never writes preferences");
                b.cancelLabels();
                test.check(a.words.move === "Wyślij", "another widget cannot cancel the editor's preview");
                a.cancelLabels();
                test.check(a.words.move !== "Wyślij" && b.words.move !== "Wyślij", "cancel restores both widgets");
                test.check(a.saveLabels(custom) && b.words.move === "Wyślij", "Apply saves labels and synchronizes peers");
                test.check(a.runtime.preferences.values.customLabels.barText === "Okna {count}", "label templates are durable");
                test.check(a.runtime.preferences.values.language === "pl" && a.runtime.preferences.values.scrollBounce === false,
                    "saving labels preserves unrelated preferences");
                var owner = transientWidget.createObject(window, {bar:bar});
                owner.previewAppearance({uiScale:1.5});
                test.check(a.uiScale === 1.5 && b.uiScale === 1.5, "transient widget owns the preview");
                owner.destroy(); test.step = 1;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
