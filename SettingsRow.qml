import QtQuick
import qs.Commons

// The owner supplies saved state; clicking never changes the switch optimistically.
Item {
    id: root
    required property string text
    property string description: ""
    property bool isSwitch: false
    property bool bordered: false
    property bool checked: false
    property color accent: Color.accent
    property var palette: null
    readonly property bool hot: pointer.containsMouse || activeFocus
    signal clicked()
    implicitHeight: Math.max(Style.space(48), captions.implicitHeight + Style.space(20))
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.5

    function activate() { if (enabled) clicked(); }
    Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) activate(); }
    Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) activate(); }
    Keys.onSpacePressed: function(event) { if (!event.isAutoRepeat) activate(); }
    Accessible.role: isSwitch ? Accessible.CheckBox : Accessible.Button
    Accessible.name: text
    Accessible.description: description
    Accessible.checkable: isSwitch
    Accessible.checked: checked
    Accessible.onPressAction: activate()
    Accessible.onToggleAction: activate()

    Rectangle {
        anchors.fill: parent; radius: Style.space(5)
        color: root.palette && root.palette.customMenu ? root.palette.menu : root.accent
        opacity: root.palette && root.palette.customMenu
            ? Math.min(1, root.palette.menuOpacity + (pointer.pressed ? 0.16 : root.hot ? 0.08 : 0))
            : pointer.pressed ? 0.16 : root.hot ? 0.08 : root.bordered ? 0.035 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Rectangle {
        anchors.fill: parent; radius: Style.space(5)
        color: "transparent"; border.width: 1; border.color: root.accent
        opacity: root.activeFocus ? 1 : root.hot ? (root.bordered ? 0.8 : 0.45) : root.bordered ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Column {
        id: captions
        anchors.left: parent.left; anchors.leftMargin: Style.space(8)
        anchors.right: indicator.left; anchors.rightMargin: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)
        Text {
            width: parent.width; text: root.text; textFormat: Text.PlainText
            wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
            color: Color.popups.text
            font.family: Style.font.family; font.pixelSize: Style.font.body + Style.space(1)
        }
        Text {
            visible: root.description !== ""
            width: parent.width; text: root.description; textFormat: Text.PlainText
            wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
            color: Qt.alpha(Color.popups.text, 0.78)
            font.family: Style.font.family; font.pixelSize: Style.font.body
        }
    }
    Item {
        id: indicator
        anchors.right: parent.right; anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(40); height: Style.space(24)
        Rectangle {
            id: switchTrack; objectName: "settingsSwitchTrack"
            anchors.centerIn: parent; visible: root.isSwitch
            width: Style.space(38); height: Style.space(20); radius: height / 2
            color: root.checked ? root.accent : Qt.alpha(Color.popups.text, 0.1)
            border.width: root.checked ? 0 : 1
            border.color: Qt.alpha(Color.popups.text, 0.35)
            // Keep on/off direction stable even when the surrounding row mirrors.
            LayoutMirroring.enabled: false
            Rectangle {
                width: Style.space(14); height: width; radius: width / 2
                x: root.checked ? parent.width - width - Style.space(3) : Style.space(3)
                anchors.verticalCenter: parent.verticalCenter
                readonly property real brightness: 0.2126 * root.accent.r + 0.7152 * root.accent.g + 0.0722 * root.accent.b
                color: root.checked ? (brightness > 0.6 ? "#181820" : "#ffffff") : Qt.alpha(Color.popups.text, 0.65)
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            anchors.centerIn: parent; visible: !root.isSwitch
            text: root.LayoutMirroring.enabled ? "‹" : "›"; textFormat: Text.PlainText
            color: root.hot || root.bordered ? root.accent : Qt.alpha(Color.popups.text, 0.5)
            font.family: Style.font.family; font.pixelSize: Style.font.subtitle
        }
    }
    MouseArea {
        id: pointer; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(Qt.MouseFocusReason); root.activate(); }
    }
}
