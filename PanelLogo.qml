import QtQuick
import QtQuick.Window
import "LogoCatalog.js" as Catalog

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
    property bool playbackAttempted: false
    property string playbackSource: ""
    property Item hintAnchor: root
    property string hintText: root.hostWidget ? root.hostWidget.words.logoHint : ""
    readonly property bool playing: visible && width > 0 && height > 0 && !!Window.window && Window.window.visible
    // Settings keeps one playback session across its subpanels; invisibility
    // pauses that session rather than charging cooldown or rewinding it.
    property bool sessionActive: playing
    // A compact panel can hide its artwork while expanding without becoming a
    // new opening. Settings likewise keeps the choice across its subpanels.
    property bool selectionActive: sessionActive
    property string randomizedSource: ""
    readonly property string renderedSource: Catalog.isRandom(source) ? randomizedSource : source
    readonly property bool playbackActive: sessionActive && !!Window.window && Window.window.visible
    readonly property bool pixel: source === "builtin:omarchy-pixel"
    readonly property bool hovered: pointer.hovered
    property string motion: Catalog.motion(hostWidget && hostWidget.effectiveSettings ? hostWidget.effectiveSettings[cooldownSlot + "LogoMotion"] : "none")
    property string reveal: Catalog.reveal(hostWidget && hostWidget.effectiveSettings ? hostWidget.effectiveSettings[cooldownSlot + "LogoReveal"] : "none")
    property bool themeColors: hostWidget && hostWidget.effectiveSettings && typeof hostWidget.effectiveSettings[cooldownSlot + "LogoThemeColors"] === "boolean"
        ? hostWidget.effectiveSettings[cooldownSlot + "LogoThemeColors"] : Catalog.isRandom(source) || !!Catalog.effect(source)
    readonly property real sourceAspect: art.aspect
    readonly property bool customImageReady: art.imageReady
    readonly property bool animationRequested: playbackActive && (motion !== "none" || reveal !== "none" || pixel || (Catalog.animated(source) && customImageReady))
    function chooseRandomSource() {
        if (selectionActive && Catalog.isRandom(source)) randomizedSource = Catalog.randomSource(randomizedSource);
    }
    function finishPlayback() {
        if (playbackGranted && hostWidget && hostWidget.endLogoAnimation)
            hostWidget.endLogoAnimation(cooldownSlot, playbackSource);
        playbackGranted = false; playbackAttempted = false; playbackSource = "";
    }
    function updatePlayback() {
        if (!animationRequested) { finishPlayback(); return; }
        if (playbackAttempted && playbackSource === source) return;
        finishPlayback();
        playbackAttempted = true;
        playbackSource = source;
        playbackGranted = !hostWidget || !hostWidget.beginLogoAnimation
            || hostWidget.beginLogoAnimation(cooldownSlot, source, cooldown);
    }
    onAnimationRequestedChanged: {
        if (!animationRequested) finishPlayback();
        else Qt.callLater(updatePlayback);
    }
    onSelectionActiveChanged: if (selectionActive) chooseRandomSource()
    onSourceChanged: { chooseRandomSource(); Qt.callLater(updatePlayback); }
    Component.onCompleted: { if (!randomizedSource) chooseRandomSource(); Qt.callLater(updatePlayback); }
    Component.onDestruction: finishPlayback()
    LogoArt {
        id: art; anchors.fill: parent
        source: root.renderedSource; accent: root.accent; themeColors: root.themeColors; motion: root.motion; reveal: root.reveal
        artworkOpacity: Catalog.opacity(root.hostWidget && root.hostWidget.effectiveSettings ? root.hostWidget.effectiveSettings[root.cooldownSlot + "LogoOpacity"] : undefined, root.source)
        pendingPlayback: root.animationRequested && (!root.playbackAttempted || root.playbackSource !== root.source)
        playing: root.playbackActive && root.playbackGranted; suspended: !root.playing
        loopAnimation: root.loopAnimation; loopDelay: root.loopDelay
    }
    HoverHandler { id: pointer }
    PanelHint {
        objectName: "logoHint"
        hostWidget: root.hostWidget
        belowAnchor: true
        anchorItem: root.hintAnchor
        scaleItem: root.parent
        requested: pointer.hovered
        text: root.hintText
    }
}
