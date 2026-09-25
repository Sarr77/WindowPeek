import QtQuick
import qs.Commons
import QtQml.Models
import qs.Ui as Ui
import "TextReadability.js" as Readability

// Keep the shell's native button layout, input and theme. Only decorate its
// read-only labels; no background rectangle or extra rendering surface.
Ui.Button {
    id: root
    readonly property var shadowHost: Readability.hostFor(root)
    readonly property color shadowBacking: Readability.backingFor(root)
    readonly property var nativeLabels: Readability.textItems(root)
    Instantiator {
        model: root.nativeLabels
        delegate: QtObject {
            required property var modelData
            readonly property color originalInk: root.selected ? root._selectedColor : root.foreground
            readonly property var readability: root.visible && modelData.visible ? Readability.decision(root.shadowHost, originalInk, Color.popups.text, root.shadowBacking) : ({active:false,ink:originalInk})
            readonly property bool active: readability.active
            readonly property var readableInk: readability.ink
            property Binding inkColor: Binding {
                target: modelData; property: "color"
                value: Qt.rgba(readableInk.r, readableInk.g, readableInk.b, readableInk.a)
            }
            property Binding textStyle: Binding {
                target: modelData; property: "style"
                value: active ? Text.Raised : Text.Normal
            }
            property Binding haloColor: Binding {
                target: modelData; property: "styleColor"
                value: Readability.halo(modelData.color)
            }
        }
    }
}
