import QtQuick
import "LogoCatalog.js" as Catalog

// A single opening pass over the live artwork. GIF playback has its own clock.
// The capture layer exists only during the reveal, never while the panel is idle.
Item {
    id: root
    property string kind: "none"
    property string sourceKey: ""
    property bool playing: false
    property bool preparing: false
    property bool ready: false
    property bool suspended: false
    property size imageSize: Qt.size(1, 1)
    property real progress: 1
    property bool shaderFailed: false
    readonly property bool supported: GraphicsInfo.api !== GraphicsInfo.Software && !shaderFailed
    readonly property bool requested: playing && ready && Catalog.reveal(kind) !== "none"
    readonly property bool active: requested && progress < 1
    readonly property bool animating: animation.running && !animation.paused
    // Playback approval and async decoding can finish after the first paint.
    // Keep just the artwork concealed until the reveal can own that first frame.
    readonly property real contentOpacity: preparing && Catalog.reveal(kind) !== "none"
        ? 0 : active && !supported ? progress : 1
    function restart() {
        animation.stop(); progress = requested ? 0 : 1;
        if (requested) animation.start();
    }
    onRequestedChanged: restart()
    onKindChanged: if (requested) restart()
    onSourceKeyChanged: restart()
    NumberAnimation {
        id: animation; target: root; property: "progress"
        from: 0; to: 1; duration: 1200; easing.type: Easing.InOutQuad
        paused: running && root.suspended
    }
    property Component shader: Component {
        ShaderEffect {
            objectName: "logoRevealShader"
            property var source
            property real phase: root.progress
            property real mode: Catalog.reveals.indexOf(root.kind)
            property real imageWidth: root.imageSize.width
            property real imageHeight: root.imageSize.height
            fragmentShader: Qt.resolvedUrl("assets/shaders/logo-reveal.frag.qsb")
            onStatusChanged: if (status === ShaderEffect.Error) root.shaderFailed = true
        }
    }
}
