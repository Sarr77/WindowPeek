import QtQuick
import qs.Ui as Ui
import qs.Commons

// User labels keep the native button's input and styling, with bounded text.
ReadableButton {
    id: root
    property string label: ""
    property int activationFocusReason: Qt.MouseFocusReason
    Keys.forwardTo: [keyboardActivation]
    Item {
        id: keyboardActivation
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.activationFocusReason = Qt.TabFocusReason;
            event.accepted = false;
        }
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressedChanged: if (pressed) root.activationFocusReason = Qt.MouseFocusReason
    }
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
