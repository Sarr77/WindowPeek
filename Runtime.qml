pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Appearance.js" as Appearance

QtObject {
    id: root
    readonly property string version: "0.7.2"
    property WindowState state: WindowState { }
    property FocusRecovery recovery: FocusRecovery {
        state: root.state
        onNotification: function(text) {
            if (Quickshell.env("QT_QPA_PLATFORM") !== "offscreen")
                Quickshell.execDetached(["notify-send", "--app-name=WindowPeek", "--expire-time=6000", "WindowPeek", text]);
        }
    }
    property WindowActions actions: WindowActions { state: root.state }
    property Preferences preferences: Preferences { }
    property WallpaperSource wallpaper: WallpaperSource { }
    property var fallbackSettings: null
    property bool publishingSettings: false
    property Updates updates: Updates { preferences: root.preferences }
    property var previewOwner: null
    property var previewAppearance: ({})
    property string themeId: ""
    property var labelsPreviewOwner: null
    property var labelsPreview: ({})
    // Session-only history across monitors, independent or shared between slots.
    property var logoAnimationHistory: ({})
    function beginLogoAnimation(slot, source, cooldown, shared) {
        if (!slot) return true;
        var now = Date.now(), last = logoAnimationHistory[shared ? "shared" : slot];
        if (cooldown > 0 && last && (shared || last.source === source)
                && ((shared && last.active) || (now >= last.at && now - last.at < cooldown * 1000))) return false;
        logoAnimationHistory[slot] = {source: source, at: now, active: true};
        if (shared) logoAnimationHistory.shared = {source: source, slot: slot, at: now, active: true};
        return true;
    }
    function endLogoAnimation(slot, source) {
        var last = logoAnimationHistory[slot];
        if (last && last.source === source) { last.at = Date.now(); last.active = false; }
        var shared = logoAnimationHistory.shared;
        if (shared && shared.slot === slot && shared.source === source) {
            shared.at = Date.now(); shared.active = false;
        }
    }

    function preview(owner, value) { previewAppearance = value; previewOwner = owner; }
    function cancelPreview(owner) { if (previewOwner === owner) { previewOwner = null; previewAppearance = {}; } }
    function previewLabels(owner, value) { labelsPreview = value; labelsPreviewOwner = owner; }
    function cancelLabels(owner) { if (labelsPreviewOwner === owner) { labelsPreviewOwner = null; labelsPreview = {}; } }

    property FileView theme: FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/current/theme.name"
        watchChanges: true
        printErrors: false
        onLoaded: root.themeId = Appearance.themeId(text())
        onFileChanged: reload()
        onLoadFailed: root.themeId = ""
    }
}
