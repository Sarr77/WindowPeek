import QtQuick
import qs.Ui as Ui
import qs.Commons

// User labels keep the native button's input and styling, with bounded text.
Ui.Button {
    id: root
    property string label: ""
    readonly property real captionInsets: horizontalPadding * 2 + _reservedBorderLeft + _reservedBorderRight
    implicitWidth: naturalCaption.advanceWidth + captionInsets
    text: caption.elidedText
    Accessible.name: label
    TextMetrics {
        id: naturalCaption
        text: root.label
        font.family: root.fontFamily; font.pixelSize: root.fontSize; font.bold: root.selected
    }
    TextMetrics {
        id: caption
        text: root.label
        font.family: root.fontFamily; font.pixelSize: root.fontSize; font.bold: root.selected
        elide: Text.ElideRight
        elideWidth: Math.max(0, root.width - root.captionInsets)
    }
}
