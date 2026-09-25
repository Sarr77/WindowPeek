import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int cleanupWaits: 0
    TestCase { id: asyncWait; when:false }
    function saved(widget, method, values) {
        var accepted = values === undefined ? widget[method]() : widget[method](values);
        for (var i=0; widget.runtime.preferences.saving && i<2000; i++) asyncWait.wait(1);
        check(!widget.runtime.preferences.saving, "atomic save completes without blocking the UI event loop");
        return accepted && !widget.runtime.preferences.failed;
    }
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
            if (!a.settingsReady || !b.settingsReady || a.runtime.preferences.saving) return;
            stop();
            try {
                if (test.step === 1) {
                    // QObject.destroy() is deferred; queued timer ticks can run
                    // first after the fixture's many synchronous durable writes.
                    if ((a.uiScale !== a.savedAppearance.uiScale || b.uiScale !== b.savedAppearance.uiScale)
                            && ++test.cleanupWaits < 10) { restart(); return; }
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
                    && a.hints.mode === "auto" && a.hints.used === 0 && a.hints.remaining === 100 && a.hints.enabled,
                    "fresh defaults leave theme assessment pending and start the full 100-display hint budget");
                test.check(!a.followBarStyle && !b.followBarStyle, "following the bar is opt-in");
                test.check(!a.keepSearchFocus && !b.keepSearchFocus, "strict focus is opt-in");
                a.runtime.preferences.readBlocked = true;
                test.check(!test.saved(a,"persistSettings",{keepSearchFocus:true}) && !a.keepSearchFocus && !b.keepSearchFocus,
                    "blocked durable write cannot enable protection");
                a.runtime.preferences.readBlocked = false;
                test.check(test.saved(a,"persistSettings",{keepSearchFocus:true}) && b.keepSearchFocus && a.keepSearchFocus,
                    "explicit focus choice synchronizes monitors");
                test.check(a.runtime.preferences.values.keepSearchFocus === true, "focus choice is durable");
                test.check(test.saved(b,"persistSettings",{keepSearchFocus:false}) && !a.keepSearchFocus, "either monitor can disable");
                var legacyLogo=String(Qt.resolvedUrl("WindowPeek/vendor/omarchy/logo.svg"));
                test.saved(a,"persistSettings",{logoImage:legacyLogo});
                test.check(a.hoverLogoImage===legacyLogo && b.settingsLogoImage===legacyLogo,"legacy shared image remains on both logos");
                test.saved(b,"persistSettings",{settingsLogoImage:"builtin:omarchy-pixel"});
                test.check(a.settingsLogoImage==="builtin:omarchy-pixel" && a.hoverLogoImage===legacyLogo,"Settings selection changes independently across monitors");
                test.saved(a,"persistSettings",{hoverLogoImage:""});
                test.check(b.hoverLogoImage==="" && b.settingsLogoImage==="builtin:omarchy-pixel","explicit reset overrides only one legacy logo");
                test.check(a.runtime.preferences.values.hoverLogoImage==="" && a.runtime.preferences.values.settingsLogoImage==="builtin:omarchy-pixel","both choices are durable");
                test.check(a.hoverLogoLoop && b.settingsLogoLoop,"both logo animations loop by default");
                test.check(a.hoverLogoLoopDelay===4.2 && b.settingsLogoLoopDelay===4.2,"default delay preserves the original pixel pause");
                test.saved(a,"persistSettings",{hoverLogoLoopDelay:0.3,settingsLogoLoopDelay:2});
                test.check(b.hoverLogoLoopDelay===0.3 && b.settingsLogoLoopDelay===2,"fractional and whole logo delays are independent and shared");
                test.saved(a,"persistSettings",{hoverLogoLoop:false});
                test.check(!b.hoverLogoLoop && b.settingsLogoLoop,"compact playback is independent and shared across monitors");
                test.saved(b,"persistSettings",{settingsLogoLoop:false});
                test.check(!a.settingsLogoLoop && !a.runtime.preferences.values.hoverLogoLoop
                    && !a.runtime.preferences.values.settingsLogoLoop,"both playback choices are durable");
                test.check(test.saved(a,"persistSettings",{followBarStyle:true}) && a.panelStyle === "solid" && b.panelStyle === "solid",
                    "opaque local bar overrides the rendered wallpaper");
                test.check(a.selectedPanelStyle === "wallpaper" && a.runtime.preferences.values.panelStyle !== "solid",
                    "bar following preserves the selected background");
                bar.transparent = true;
                test.check(a.panelStyle === "wallpaper" && b.panelStyle === "wallpaper", "bar transparency changes react immediately");
                bar.transparent = false;
                test.saved(a,"persistSettings",{followBarStyle:false});
                test.check(a.panelStyle === "wallpaper", "turning follow off restores the chosen background");
                test.check(test.saved(a,"persistSettings",{panelStyle:"glass"}) && a.glassPanels && b.glassPanels,
                    "glass setting synchronizes across monitors");
                test.check(test.saved(b,"persistSettings",{panelStyle:"solid",backgroundTexture:false}) && !a.glassPanels && !b.glassPanels
                    && !a.backgroundTexture && !b.backgroundTexture,
                    "explicit Solid and disabled grain still override the new defaults on both monitors");
                test.check(a.panelHoverDelay === 400 && a.previewHoverDelay === 400 && a.popupAnimations && a.openOnHover,
                    "existing behavior is the default");
                test.check(test.saved(a,"persistSettings",{panelHoverDelay:0, previewHoverDelay:1250, popupAnimations:false, openOnHover:false}), "timing preferences save");
                test.check(b.panelHoverDelay === 0 && b.previewHoverDelay === 1250 && !b.popupAnimations && !b.openOnHover,
                    "timing preferences synchronize across monitors");
                test.check(a.runtime.preferences.values.panelHoverDelay === 0 && a.runtime.preferences.values.popupAnimations === false && !a.runtime.preferences.values.openOnHover,
                    "zero and disabled animations are durable");
                test.check(a.windowPreviews && b.windowPreviews, "window previews default on");
                test.check(test.saved(a,"persistSettings",{windowPreviews:false}) && !a.windowPreviews && !b.windowPreviews,
                    "disabling window previews synchronizes monitors");
                test.check(a.runtime.preferences.values.windowPreviews === false, "disabled previews are saved");
                test.check(test.saved(b,"persistSettings",{windowPreviews:true}) && a.windowPreviews && b.windowPreviews,
                    "either monitor can restore window previews");
                test.check(a.scrollBounce && b.scrollBounce, "springy scrolling defaults on");
                test.check(test.saved(a,"persistSettings",{ scrollBounce: true }) && a.scrollBounce && b.scrollBounce,
                    "enabling springy scrolling updates both monitors");
                test.check(test.saved(a,"persistSettings",{ scrollBounce: false }) && !a.scrollBounce && !b.scrollBounce,
                    "disabling springy scrolling updates both monitors");
                test.check(test.saved(a,"persistSettings",{ hintsMode: "auto", hintsUsed: 98 }), "save hint budget");
                test.check(test.saved(a,"recordHintShown") && test.saved(b,"recordHintShown"), "shared hint budget across monitors");
                test.check(a.hints.used === 100 && b.hints.used === 100 && !a.hints.enabled, "budget exhausted exactly once");
                test.check(!test.saved(b,"recordHintShown"), "no 101st automatic hint");
                test.check(test.saved(a,"toggleHints") && b.hints.enabled, "manual hints override budget");
                test.check(a.runtime.preferences.values.hintsMode === "on", "manual on is durable");
                for (var hover = 0; hover < 250; hover++) {
                    test.check(!test.saved(b,"recordHintShown") && b.hints.enabled, "manual hints remain enabled beyond the automatic limit");
                }
                test.check(test.saved(b,"toggleHints") && !a.hints.enabled && a.runtime.preferences.values.hintsMode === "off",
                    "manual off is shared and durable");
                test.check(test.saved(a,"toggleHints") && b.hints.enabled, "manual hints can be enabled again without resetting the used count");
                test.check(test.saved(a,"persistSettings",{ includeSpecial: false }) && !a.includeSpecial && !b.includeSpecial,
                    "explicit exclusion overrides the new default on both monitors");
                test.check(test.saved(a,"persistSettings",{ includeSpecial: true }), "special preference saved");
                test.check(b.includeSpecial && shell.saved.hintsUsed === 100, "rapid saves preserve other values");
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
                test.check(test.saved(a,"saveLabels",custom) && b.words.move === "Wyślij", "Apply saves labels and synchronizes peers");
                test.check(a.runtime.preferences.values.customLabels.barText === "Okna {count}", "label templates are durable");
                test.check(a.runtime.preferences.values.language === "pl" && a.runtime.preferences.values.scrollBounce === false,
                    "saving labels preserves unrelated preferences");
                // Enqueue independent changes before either disk write completes.
                a.persistSettings({panelHoverDelay:333});
                b.persistSettings({previewHoverDelay:777});
                test.check(a.runtime.preferences.requestedValues.panelHoverDelay===333,"second monitor merges the pending first edit");
                test.saved(a,"persistSettings",{});
                test.check(a.panelHoverDelay===333 && b.previewHoverDelay===777,"queued edits from both monitors survive");
                test.saved(a,"persistSettings",{hintsMode:"auto",hintsUsed:98});
                test.check(a.recordHintShown() && b.recordHintShown() && !a.recordHintShown(),"queued hints reserve the shared budget exactly once");
                test.saved(a,"persistSettings",{});
                test.check(a.hints.used===100 && b.hints.used===100,"both reserved hints are committed");
                var owner = transientWidget.createObject(window, {bar:bar});
                owner.previewAppearance({uiScale:1.5});
                test.check(a.uiScale === 1.5 && b.uiScale === 1.5, "transient widget owns the preview");
                owner.destroy(); test.step = 1; restart();
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
