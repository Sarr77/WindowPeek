import QtQuick
import "WindowPeek/WindowModel.js" as Model
import "WindowPeek/Appearance.js" as Appearance
import "WindowPeek/I18n.js" as I18n
import "WindowPeek/Settings.js" as Settings
import "WindowPeek/Labels.js" as Labels

QtObject {
    property var bar: null
    property bool opened: false
    property var settings: ({ language: "en", includeSpecial: true, hintsMode: "auto", hintsUsed: 0 })
    property string language: "en"
    property string languageSetting: "en"
    property string detectedLanguage: "en"
    readonly property var savedLabels: Labels.normalize(settings)
    property var labelsPreview: null
    readonly property var labels: labelsPreview || savedLabels
    readonly property var words: Labels.apply(I18n.words(language), labels)
    readonly property var textTemplates: Labels.templates(I18n.words(language), labels, setting("barLabel", "full"), false)
    readonly property var hints: Settings.hints(settings)
    property bool includeSpecial: true
    readonly property bool windowPreviews: setting("windowPreviews", true) === true
    readonly property bool openOnHover: setting("openOnHover", true) === true
    readonly property int panelHoverDelay: Settings.hoverDelay(setting("panelHoverDelay", 400))
    readonly property int previewHoverDelay: Settings.hoverDelay(setting("previewHoverDelay", 400))
    readonly property bool popupAnimations: setting("popupAnimations", true) === true
    readonly property bool scrollBounce: setting("scrollBounce", true) === true
    property var savedAppearance: Appearance.normalize({})
    property var appearance: savedAppearance
    property string themeId: "tokyo-night"
    property color themeAccent: "#7AA2F7"
    readonly property color accent: Appearance.resolve(appearance, themeId, String(themeAccent))
    readonly property real uiScale: appearance.uiScale
    property real effectiveBarScale: 1
    property bool actionBusy: false
    property string actionError: ""
    property bool saveFailed: false
    property bool rejectSave: false
    property bool autoUpdates: true
    property bool updatesAvailable: false
    property string focused: ""
    property string moved: ""
    property string brought: ""
    property string destinationRequested: ""
    property bool moveMenuOpen: false
    property var windowPreview: null
    property var snapshot: ({
        clients: [
            { address: "0x1", class: "code", app: "Editor", title: "Atlas project", workspace: { id: 1, name: "1" }, grouped: ["0x1", "0x2"] },
            { address: "0x2", class: "code", app: "Editor", title: "Project notes", hidden: true, workspace: { id: 1, name: "1" }, grouped: ["0x1", "0x2"] },
            { address: "0x3", class: "chromium", app: "Browser", title: "Documentation", workspace: { id: 4, name: "4" } },
            { address: "0x4", class: "foot", app: "Terminal", title: "Build output", workspace: { id: -1337, name: "Studio" } },
            { address: "0x5", class: "org.example.Notes", app: "Notes", title: "Reading list", workspace: { id: -99, name: "special:scratchpad" } }
        ],
        workspaces: [{ id: 1, name: "1", monitorID: 7 }, { id: 4, name: "4", monitorID: 8 }, { id: -1337, name: "Studio", monitorID: 8 }],
        monitors: [{ id: 7, name: "TEST-A", activeWorkspace: { id: 1 } }, { id: 8, name: "TEST-B", activeWorkspace: { id: 4 } }],
        activeAddress: "0x1"
    })
    readonly property var inventory: Model.normalize(snapshot)
    signal moveCompleted()
    function preference(name, fallback) { return setting(name, fallback); }
    function setting(key, fallback) { return settings[key] === undefined ? fallback : settings[key]; }
    function persistSettings(values) {
        if (rejectSave) { saveFailed = true; return false; }
        saveFailed = false;
        settings = Settings.merge(settings, values, "sarr.windowpeek");
        if (values.includeSpecial !== undefined) includeSpecial = values.includeSpecial;
        return true;
    }
    function setLanguage(value) { language = value; languageSetting = value; return persistSettings({ language: value }); }
    function recordHintShown() { return hints.mode === "auto" && hints.remaining > 0 && persistSettings({ hintsUsed: hints.used + 1 }); }
    function toggleHints() { return persistSettings({ hintsMode: hints.enabled ? "off" : "on" }); }
    function toggleUpdates() { autoUpdates = !autoUpdates; }
    function previewAppearance(values) { appearance = Appearance.merge(savedAppearance, values); }
    function cancelAppearance() { appearance = savedAppearance; }
    function saveAppearance(values) {
        if (rejectSave) { saveFailed = true; return false; }
        saveFailed = false;
        savedAppearance = Appearance.merge(savedAppearance, values); appearance = savedAppearance; return true;
    }
    function focusWindow(address) { focused = address; return true; }
    function chooseDestination(address) {
        if (actionBusy || !inventory.windows.some(function(window) { return window.address === address; })) return false;
        destinationRequested = address; return true;
    }
    function bringWindow(address) { brought = address; return true; }
    function moveWindow(address, destination) { moved = address + ":" + destination; return true; }
    function clearError() { actionError = ""; }
    function panelClosed() { cancelAppearance(); cancelLabels(); }
    function previewLabels(values) { labelsPreview = Labels.normalize(values); }
    function cancelLabels() { labelsPreview = null; }
    function saveLabels(values) {
        if (!Labels.valid(values) || !persistSettings(Labels.normalize(values))) return false;
        cancelLabels(); return true;
    }
}
