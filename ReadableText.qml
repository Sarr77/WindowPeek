import QtQuick
import qs.Commons
import "TextReadability.js" as Readability

// Solid letter cores and a one-pixel shadow; no enclosing outline or layer.
Text {
    id: root
    property var shadowHost: Readability.hostFor(parent)
    property color shadowBacking: Readability.backingFor(parent)
    property color textColor: Color.popups.text
    readonly property var readability: visible ? Readability.decision(shadowHost, textColor, Color.popups.text, shadowBacking) : ({active:false,ink:textColor})
    readonly property bool shadowActive: readability.active
    readonly property var readableInk: readability.ink
    color: Qt.rgba(readableInk.r, readableInk.g, readableInk.b, readableInk.a)
    style: shadowActive ? Text.Raised : Text.Normal
    styleColor: Readability.halo(color)
}
