import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Commons

// Draw the same centered crop as Omarchy, then expose only this card's area.
// An opaque backing also covers underlying windows while the image is loading.
ClippingRectangle {
    id: root
    property url source: ""
    property bool pending: false
    property var palette: null
    readonly property color tint: palette ? palette.panel : Color.popups.background
    property size screenSize: Qt.size(0, 0)
    property point screenOrigin: Qt.point(0, 0)
    property real displayScale: 1
    property real tintOpacity: 0.30
    property bool wallpaper: true
    property bool blurred: false
    property bool textured: false
    readonly property bool ready: wallpaperImage.status === Image.Ready
    readonly property bool readyToShow: !wallpaper || (!pending
        && (ready || wallpaperImage.status === Image.Error || String(source) === ""))
    color: wallpaper ? Qt.alpha(tint, 1) : "transparent"
    Item {
        id: sample
        // Include neighboring wallpaper pixels so blur has no dark edge seam.
        readonly property real margin: 24 / root.displayScale
        x: -margin; y: -margin
        width: root.width + margin * 2; height: root.height + margin * 2
        clip: true; visible: root.wallpaper
        layer.enabled: root.wallpaper && (root.blurred || (root.palette && root.palette.wallpaperBrightness !== 0))
        layer.effect: MultiEffect {
            blurEnabled: root.blurred; blurMax: 16; blur: 0.6; autoPaddingEnabled: false
            brightness: root.palette ? root.palette.wallpaperBrightness : 0
        }
        Image {
            id: wallpaperImage; objectName: "alignedWallpaperImage"
            source: root.wallpaper ? root.source : ""
            x: -root.screenOrigin.x / root.displayScale + sample.margin
            y: -root.screenOrigin.y / root.displayScale + sample.margin
            width: root.screenSize.width / root.displayScale
            height: root.screenSize.height / root.displayScale
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; cache: true; retainWhileLoading: true
        }
    }
    Rectangle { anchors.fill: parent; visible: root.wallpaper; color: Qt.alpha(root.tint, root.tintOpacity) }
    Image {
        anchors.fill: parent; visible: root.textured
        source: root.textured ? Qt.resolvedUrl(root.palette && root.palette.customGrain ? "assets/grain-tint.svg" : "assets/grain.svg") : ""
        sourceSize: Qt.size(64, 64); fillMode: Image.Tile
        opacity: root.palette ? root.palette.grainOpacity : 0.045; smooth: false
        layer.enabled: !!root.palette && root.palette.customGrain
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.palette ? root.palette.grain : "white"
        }
    }
}
