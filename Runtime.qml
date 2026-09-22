pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Appearance.js" as Appearance

QtObject {
    id: root
    readonly property string version: "0.7.1"
    property WindowState state: WindowState { }
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
