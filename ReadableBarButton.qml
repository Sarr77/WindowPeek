import QtQuick
import QtQml.Models
import "vendor/omarchy" as Choice
import qs.Commons
import "TextReadability.js" as Readability

// The bar has its own background and adaptive foreground. Panel wallpaper
// samples do not describe it, even when its label opens that panel. The idle
// label keeps the shell's original rendering; only its active accent is helped.
Choice.WidgetButton {
    animateTextColor: false
    id: root
    required property var hostWidget
    property color activeFallbackColor: foreground
    readonly property var nativeLabels: Readability.textItems(root)
    readonly property QtObject contrastContext: QtObject {
        readonly property string textShadowMode: root.hostWidget.textShadowMode
        readonly property string panelStyle: root.bar && root.bar.transparent ? "glass" : "wallpaper"
        readonly property real glassTransparency: 100
        readonly property real wallpaperTransparency: 0
        readonly property var surfaces: ({panel: root.bar ? root.bar.background : Color.bar.background})
    }
    Instantiator {
        model: root.nativeLabels
        delegate: QtObject {
            required property var modelData
            readonly property color originalInk: root.active && root.useActiveColor ? root.activeColor : root.foreground
            readonly property bool correctActive: root.active && root.useActiveColor
            readonly property bool shadowActive: correctActive && Readability.needed(root.contrastContext, originalInk)
            readonly property var readableInk: correctActive
                ? Readability.ink(root.contrastContext, originalInk, root.activeFallbackColor) : originalInk
            property Binding inkColor: Binding {
                target: modelData; property: "color"
                value: Qt.rgba(readableInk.r, readableInk.g, readableInk.b, readableInk.a)
            }
            property Binding textStyle: Binding {
                target: modelData; property: "style"
                value: shadowActive ? Text.Raised : Text.Normal
            }
            property Binding haloColor: Binding {
                target: modelData; property: "styleColor"
                value: Readability.halo(readableInk)
            }
        }
    }
}
