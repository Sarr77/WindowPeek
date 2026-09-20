import QtQuick
import Quickshell
import Quickshell.Wayland
import "PopupPlacement.js" as Placement

// Layer-shell uses Omarchy's existing no-animation rule for this surface role.
PanelWindow {
    id: root
    property var preview: null
    visible: !!preview && preview.visible && preview.instant
    screen: preview && preview.anchorWindow ? preview.anchorWindow.screen : null
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-keyboard-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: preview ? preview.width : 1
    implicitHeight: preview ? preview.height : 1
    // The parent panel spans its monitor. Layer-shell does not expose global
    // window positions to Qt, so use its scene coordinates and screen origin.
    readonly property rect globalBounds: {
        if (!preview || !screen) return Qt.rect(0, 0, 0, 0);
        var bounds = preview.boundsRect;
        return Qt.rect(screen.x + bounds.x, screen.y + bounds.y, bounds.width, bounds.height);
    }
    readonly property point origin: {
        if (!screen || !preview) return Qt.point(0, 0);
        var point = Placement.beside(globalBounds, preview.rowRect.y - preview.boundsRect.y,
            preview.rowRect.height, preview.width, preview.height, screen);
        return Qt.point(point.x, point.y);
    }
    margins.left: origin.x
    margins.top: origin.y
}
