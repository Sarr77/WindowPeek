import QtQuick
import QtQuick.Shapes
import qs.Commons

ActionButton {
    id: root
    property bool discussion: false
    readonly property color iconColor: discussion ? accent : "#e9b44c"
    fontSize: Style.font.title
    implicitHeight: Math.max(Style.space(48), caption.implicitHeight + Style.space(20))
    contentItem: Item {
        Shape {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20; scale: Style.space(20) / 20; transformOrigin: Item.Left
            ShapePath {
                fillColor: root.discussion ? "transparent" : Qt.alpha(root.iconColor, 0.18)
                strokeColor: root.iconColor
                strokeWidth: 1.5; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.discussion
                        ? "M3 3 H17 V14 H9 L4 18 V14 H3 Z M6 7 H14 M6 10 H12"
                        : "M10 1.8 L12.5 7 L18.2 7.8 L14.1 11.8 L15.1 17.5 L10 14.8 L4.9 17.5 L5.9 11.8 L1.8 7.8 L7.5 7 Z"
                }
            }
        }
        ReadableText {
            id: caption
            anchors.left: parent.left; anchors.leftMargin: Style.space(30)
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: root.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
            textColor: root.foreground; font.family: Style.font.family; font.pixelSize: root.fontSize
        }
    }
}
