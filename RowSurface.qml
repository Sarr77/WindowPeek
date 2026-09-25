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
    property bool glass: false
    property color fillColor: Color.popups.background
    property real fillOpacity: glass ? 0.52 : 0
    readonly property color readabilityBackground: Qt.alpha(fillColor, fillOpacity)
    readonly property bool emphasized: selected || activeFocus || pressed

    radius: Style.space(5)
    color: Qt.alpha(fillColor, fillOpacity)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.pressed ? Qt.alpha(root.accent, 0.22)
            : root.hovered ? Qt.alpha(root.accent, 0.12)
            : root.selected || root.activeFocus ? Qt.alpha(root.accent, 0.08)
            : root.currentWindow ? Qt.alpha(root.accent, 0.045) : Qt.alpha(Color.popups.text, 0.025)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

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
