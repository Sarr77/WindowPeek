import QtQuick
import "vendor/omarchy" as Choice

// A stepped glint over the existing Omarchy wordmark. All colors come from the
// theme; the original SVG paths and their attribution remain unchanged.
Item {
    id: root
    property color accent: "white"
    property bool playing: false
    property bool suspended: false
    property bool loopAnimation: true
    property real loopDelay: 4.2
    property real progress: 0
    readonly property bool animating: sweep.running && !sweep.paused
    readonly property real cell: width / 81
    clip: true
    onPlayingChanged: if (!playing) progress = 0
    // Let dependent loops/duration bindings settle before restarting an already
    // running animation; otherwise Qt can retain the previous infinite loop.
    onLoopAnimationChanged: if (playing) Qt.callLater(function() { if (root && root.playing) sweep.restart(); })
    onLoopDelayChanged: if (playing && loopAnimation) Qt.callLater(function() { if (root && root.playing) sweep.restart(); })
    Choice.OmarchyLogo { anchors.fill: parent; color: Qt.alpha(root.accent, 0.16) }
    Repeater {
        model: [{offset:0, cells:10, alpha:0.10}, {offset:2, cells:6, alpha:0.14}, {offset:4, cells:2, alpha:0.18}]
        delegate: Item {
            required property var modelData
            x: (Math.floor(root.progress * 91) - 10 + modelData.offset) * root.cell
            width: root.cell * modelData.cells; height: root.height
            clip: true; visible: root.playing
            Choice.OmarchyLogo {
                x: -parent.x; width: root.width; height: root.height
                color: Qt.alpha(root.accent, parent.modelData.alpha)
            }
        }
    }
    SequentialAnimation {
        id: sweep; running: root.playing; paused: root.suspended && running; loops: root.loopAnimation ? Animation.Infinite : 1
        NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: 2400 }
        PauseAnimation { duration: root.loopAnimation ? root.loopDelay * 1000 : 0 }
    }
}
