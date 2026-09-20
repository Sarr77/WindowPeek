import QtQuick
import qs.Commons

// Fill and outlines render separately; hover never changes outline colors.
Rectangle {
    id: root
    property color accent: Color.accent
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool currentWindow: false
    readonly property bool emphasized: selected || activeFocus || pressed

    radius: Style.space(5)
    color: pressed ? Qt.alpha(accent, 0.22)
        : hovered ? Qt.alpha(accent, 0.12)
        : selected || activeFocus ? Qt.alpha(accent, 0.08)
        : currentWindow ? Qt.alpha(accent, 0.045) : Qt.alpha(Color.popups.text, 0.025)
    Behavior on color { ColorAnimation { duration: 120 } }

    // Crossfade static outlines instead of animating the fill rectangle's pen.
    // These passive items leave pointer delivery and scroll handling unchanged.
    Rectangle {
        objectName: "restingOutline"
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Color.popups.text, 0.16)
        opacity: root.emphasized || root.hovered ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Rectangle {
        objectName: "accentOutline"
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.accent
        opacity: root.emphasized ? 1 : root.hovered ? 0.8 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
