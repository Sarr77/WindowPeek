import QtQuick
import QtQuick.Window
import Quickshell
import qs.Ui as Ui
import qs.Commons

// Wallpaper is painted afresh, so controls underneath never show through a menu.
Ui.BorderSurface {
    id: root
    objectName: "dropdownBackground"
    property var hostWidget: null
    property real uiScale: 1
    property color fallbackBackground: Color.popups.background
    readonly property bool wallpaperMode: !!hostWidget && hostWidget.panelStyle === "wallpaper"
    readonly property var targetWindow: root.Window.window
    readonly property point wallpaperOrigin: {
        placementWatcher.transform;
        return targetWindow ? backdrop.mapToItem(targetWindow.contentItem, 0, 0) : Qt.point(0, 0);
    }
    color: wallpaperMode ? Qt.alpha(hostWidget.surfaces.panel, 1) : fallbackBackground

    TransformWatcher {
        id: placementWatcher
        a: root.wallpaperMode && root.visible ? backdrop : null
        b: root.targetWindow ? root.targetWindow.contentItem : null
    }
    Loader {
        id: backdrop
        // Draw in window pixels, matching the panel's crop, blur and grain at
        // every UI scale. Foreground options retain their normal scaled layout.
        x: root.borderLeft; y: root.borderTop
        width: Math.max(0, root.width - root.borderLeft - root.borderRight) * root.uiScale
        height: Math.max(0, root.height - root.borderTop - root.borderBottom) * root.uiScale
        scale: 1 / root.uiScale; transformOrigin: Item.TopLeft
        active: root.wallpaperMode && root.visible
        sourceComponent: WallpaperBackdrop {
            objectName: "dropdownWallpaper"
            palette: root.hostWidget.surfaces
            source: root.hostWidget.wallpaperSource
            blurred: root.hostWidget.backgroundBlur
            textured: root.hostWidget.backgroundTexture
            // A little more tint than the panel keeps option text legible.
            tintOpacity: Math.max(0.4, 1 - root.hostWidget.wallpaperTransparency / 100)
            screenSize: Qt.size(root.targetWindow ? root.targetWindow.width : 0,
                                root.targetWindow ? root.targetWindow.height : 0)
            screenOrigin: root.wallpaperOrigin
            radius: Math.max(0, root.radius - Math.max(root.borderTop, root.borderLeft)) * root.uiScale
        }
    }
    MouseArea {
        anchors.fill: parent; acceptedButtons: Qt.NoButton
        onWheel: function(wheel) { wheel.accepted = true; }
    }
}
