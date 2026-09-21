import QtQuick
import qs.Commons

Item {
    id: root
    required property string title
    property color accent: Color.accent
    property var palette: null
    property bool expanded: false
    readonly property alias headerItem: header
    default property alias content: body.data
    signal toggled()
    implicitHeight: layout.implicitHeight
    onExpandedChanged: toggled()
    function forceLayout() { body.forceLayout(); layout.forceLayout(); }

    data: Column {
        id: layout
        width: root.width; spacing: root.expanded ? Style.space(8) : 0
        Item {
            id: header; objectName: "sectionHeader"
            width: parent.width; height: Math.max(Style.space(48), caption.implicitHeight + Style.space(28))
            activeFocusOnTab: true
            readonly property bool hot: pointer.containsMouse || activeFocus
            Accessible.role: Accessible.Button
            Accessible.name: root.title
            Accessible.checkable: true; Accessible.checked: root.expanded
            Accessible.onPressAction: root.expanded = !root.expanded
            Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) root.expanded = !root.expanded; }
            Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) root.expanded = !root.expanded; }
            Keys.onSpacePressed: function(event) { if (!event.isAutoRepeat) root.expanded = !root.expanded; }
            Keys.onLeftPressed: root.expanded = root.LayoutMirroring.enabled
            Keys.onRightPressed: root.expanded = !root.LayoutMirroring.enabled
            Rectangle {
                anchors.fill: parent; radius: Style.space(6)
                color: root.palette && root.palette.customMenu ? root.palette.menu : root.accent
                opacity: root.palette && root.palette.customMenu
                    ? Math.min(1, root.palette.menuOpacity + (pointer.pressed ? 0.12 : header.hot ? 0.07 : root.expanded ? 0.04 : 0))
                    : pointer.pressed ? 0.16 : header.hot ? 0.1 : root.expanded ? 0.075 : 0.035
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            Rectangle {
                anchors.fill: parent; radius: Style.space(6); color: "transparent"
                border.width: 1; border.color: root.accent
                opacity: header.activeFocus ? 1 : header.hot ? 0.8 : root.expanded ? 0.55 : 0.3
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            Text {
                id: caption
                anchors.left: parent.left; anchors.leftMargin: Style.space(14)
                anchors.right: chevron.left; anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                text: root.title; textFormat: Text.PlainText
                wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
                color: Color.popups.text
                font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
            }
            Text {
                id: chevron
                anchors.right: parent.right; anchors.rightMargin: Style.space(14)
                anchors.verticalCenter: parent.verticalCenter
                text: root.expanded ? "−" : "+"; textFormat: Text.PlainText
                color: root.accent
                font.family: Style.font.family; font.pixelSize: Style.font.subtitle + Style.space(6)
            }
            MouseArea {
                id: pointer; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { header.forceActiveFocus(Qt.MouseFocusReason); root.expanded = !root.expanded; }
            }
        }
        Item {
            width: parent.width; height: body.implicitHeight + Style.space(16)
            visible: root.expanded
            Rectangle {
                anchors.fill: parent; radius: Style.space(6)
                color: root.palette && root.palette.customMenu
                    ? Qt.alpha(root.palette.menu, root.palette.menuOpacity) : Qt.alpha(Color.popups.text, 0.025)
            }
            Column {
                id: body
                x: Style.space(10); y: Style.space(8)
                width: parent.width - x * 2; spacing: Style.space(12)
            }
        }
    }
}
