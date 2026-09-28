import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "vendor/omarchy" as Choice
import "LogoCatalog.js" as Catalog

// One selected source only. The browser list has no running animations; no effect engine,
// subprocess, network request or animation generation runs on the opening path.
Item {
    id: root
    property string source: ""
    property color accent: "white"
    property bool themeColors: true
    property real artworkOpacity: 100
    property bool playing: false
    property bool pendingPlayback: false
    property bool suspended: false
    property bool loopAnimation: true
    property real loopDelay: 4.2
    property string motion: "none"
    property string reveal: "none"
    property real progress: 0
    readonly property string effect: Catalog.effect(source)
    readonly property bool posterReady: !!effect && poster.status === Image.Ready
    readonly property bool pixel: source === "builtin:omarchy-pixel"
    readonly property bool imageReady: picture.status === Image.Ready
    readonly property int status: !source || pixel ? Image.Ready : picture.status
    readonly property real aspect: effect ? 588 / 169 : source && !pixel ? picture.aspect : 1215 / 285
    readonly property bool animated: Catalog.animated(source) || motion !== "none" || Catalog.reveal(reveal) !== "none"
    readonly property bool tint: source !== "" && !pixel && themeColors && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property real phase: playing ? progress * Math.PI * 2 : 0
    onPlayingChanged: if (!playing) progress = 0
    LogoReveal {
        id: opening; objectName: "logoReveal"
        kind: root.reveal; sourceKey: root.source; playing: root.playing
        preparing: root.pendingPlayback || (root.playing && (root.status === Image.Null || root.status === Image.Loading))
        ready: root.status === Image.Ready; suspended: root.suspended
        imageSize: Qt.size(art.width, art.height)
    }
    Item {
        id: art; objectName: "naturalLogoArt"
        anchors.centerIn: parent
        width: Math.min(root.width, root.height * root.aspect)
        height: width / Math.max(0.0001, root.aspect)
        scale: root.motion === "pulse" ? 1 - 0.06 * Math.sin(root.phase / 2) : 1
        rotation: root.motion === "sway" ? 3 * Math.sin(root.phase) : root.motion === "spin" ? root.progress * 360 : 0
        opacity: Catalog.opacity(root.artworkOpacity) / 100 * (root.motion === "fade" ? 1 - 0.35 * Math.sin(root.phase / 2) : 1) * opening.contentOpacity
        layer.enabled: opening.active && opening.supported
        layer.effect: opening.shader
        transform: Translate { y: root.motion === "float" ? -6 * Math.sin(root.phase) : 0 }
        Choice.OmarchyLogo {
            anchors.fill: parent
            visible: !root.pixel && (!root.source || !root.imageReady) && !root.effect
            color: Qt.alpha(root.accent, 0.16)
        }
        PixelLogo {
            objectName: "pixelPanelLogo"; anchors.fill: parent; visible: root.pixel
            accent: root.accent; playing: root.pixel && root.playing; suspended: root.suspended
            loopAnimation: root.loopAnimation; loopDelay: root.loopDelay
        }
        Item {
            anchors.fill: parent
            layer.enabled: root.tint
            layer.effect: MultiEffect { colorization: 1; colorizationColor: root.accent }
        Image {
            id: poster
            anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectFit
            source: root.effect ? Qt.resolvedUrl("vendor/ttfx/" + root.effect + ".png") : ""
            visible: !!root.effect && (!root.playing || !root.imageReady)
        }
        LogoImage {
            id: picture; objectName: "customPanelLogo"
            anchors.fill: parent
            source: root.effect ? Qt.resolvedUrl("vendor/ttfx/" + root.effect + ".gif") : root.pixel ? "" : root.source
            knownAspect: root.effect ? 588 / 169 : 0
            sourceSize: root.effect ? Qt.size(588,169) : Qt.size(1024, 1024)
            playing: root.playing; suspended: root.suspended
            loopAnimation: root.loopAnimation; loopDelay: root.loopDelay
            visible: root.imageReady && (!root.effect || root.playing)
        }
        }
    }
    SequentialAnimation {
        id: motionAnimation
        running: root.playing && root.motion !== "none"
        paused: root.suspended && motionAnimation.running; loops: root.loopAnimation ? Animation.Infinite : 1
        NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: 2400 }
        PauseAnimation { duration: root.loopAnimation ? root.loopDelay * 1000 : 0 }
    }
}
