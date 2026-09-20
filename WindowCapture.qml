import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland

// Capture only the requested window. Frames stay in memory and are released
// when the preview closes; idle rows never allocate capture buffers.
Item {
    id: root
    property string address: ""
    property bool active: false
    readonly property var toplevel: active && address ? Hyprland.toplevels.values.find(function(window) {
        return window.address.toLowerCase().replace(/^0x/, "") === root.address.toLowerCase().replace(/^0x/, "");
    }) || null : null
    readonly property var captureSource: toplevel ? toplevel.wayland : null
    readonly property bool hasContent: capture.item ? capture.item.hasContent : false
    readonly property size sourceSize: capture.item ? capture.item.sourceSize : Qt.size(0, 0)

    Loader {
        id: capture
        anchors.fill: parent
        active: root.active && root.captureSource !== null
        sourceComponent: Item {
            readonly property bool hasContent: view.hasContent
            readonly property size sourceSize: view.sourceSize
            ScreencopyView {
                id: view; objectName: "windowCaptureView"
                anchors.centerIn: parent
                captureSource: root.captureSource
                constraintSize: Qt.size(parent.width, parent.height)
                width: implicitWidth; height: implicitHeight
                // Keep the next frame request pending. Delayed single-frame
                // requests can miss the final repaint of a static source.
                live: true; paintCursor: false
            }
        }
    }
}
