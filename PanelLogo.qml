import QtQuick
import QtQuick.Window
import "vendor/omarchy" as Choice

// Decoration stays above backdrop effects and never consumes clicks or scrolling.
Item {
    id: root
    required property var hostWidget
    property color accent: hostWidget ? hostWidget.accent : "white"
    property string source: ""
    property bool loopAnimation: true
    property real loopDelay: 4.2
    property real cooldown: 0
    property string cooldownSlot: ""
    property bool playbackGranted: false
    property string playbackSource: ""
    property Item hintAnchor: root
    readonly property bool playing: visible && width > 0 && height > 0 && !!Window.window && Window.window.visible
    // Settings keeps one playback session across its subpanels; invisibility
    // pauses that session rather than charging cooldown or rewinding it.
    property bool sessionActive: playing
    readonly property bool playbackActive: sessionActive && !!Window.window && Window.window.visible
    readonly property bool pixel: source === "builtin:omarchy-pixel"
    readonly property bool hovered: pointer.hovered
    readonly property bool customImageReady: picture.status === Image.Ready
    readonly property bool animationRequested: playbackActive && (pixel || (picture.animated && customImageReady))
    function finishPlayback() {
        if (playbackGranted && hostWidget && hostWidget.endLogoAnimation)
            hostWidget.endLogoAnimation(cooldownSlot, playbackSource);
        playbackGranted = false; playbackSource = "";
    }
    function updatePlayback() {
        if (!animationRequested) { finishPlayback(); return; }
        if (playbackSource === source) return;
        finishPlayback();
        playbackSource = source;
        playbackGranted = !hostWidget || !hostWidget.beginLogoAnimation
            || hostWidget.beginLogoAnimation(cooldownSlot, source, cooldown);
    }
    onAnimationRequestedChanged: {
        if (!animationRequested) finishPlayback();
        else Qt.callLater(updatePlayback);
    }
    onSourceChanged: Qt.callLater(updatePlayback)
    Component.onCompleted: Qt.callLater(updatePlayback)
    Component.onDestruction: finishPlayback()
    Choice.OmarchyLogo {
        anchors.fill: parent
        visible: !root.pixel && !root.customImageReady
        color: Qt.alpha(root.accent, 0.16)
    }
    PixelLogo {
        objectName: "pixelPanelLogo"
        anchors.fill: parent; visible: root.pixel
        accent: root.accent; playing: root.pixel && root.playbackActive && root.playbackGranted
        suspended: !root.playing
        loopAnimation: root.loopAnimation
        loopDelay: root.loopDelay
    }
    LogoImage {
        id: picture; objectName: "customPanelLogo"
        anchors.fill: parent
        source: root.pixel ? "" : root.source
        sourceSize: Qt.size(1600, 400)
        playing: root.playbackActive && root.playbackGranted
        suspended: !root.playing
        loopAnimation: root.loopAnimation
        loopDelay: root.loopDelay
        visible: root.customImageReady
    }
    HoverHandler { id: pointer }
    PanelHint {
        objectName: "logoHint"
        hostWidget: root.hostWidget
        belowAnchor: true
        anchorItem: root.hintAnchor
        requested: pointer.hovered
        text: root.hostWidget ? root.hostWidget.words.logoHint : ""
    }
}
