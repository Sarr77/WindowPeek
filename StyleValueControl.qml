import QtQuick
import QtQuick.Controls as QQC
import qs.Commons

Column {
    id: root
    required property var words
    required property string label
    property color accent: Color.accent
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property real defaultValue: 0
    property bool modified: value !== defaultValue
    signal changed(real value)
    signal resetRequested()
    signal ensureVisible()
    spacing: Style.space(4)
    Item {
        width: parent.width; height: Math.max(Style.space(32),labelText.implicitHeight)
        Text {
            id: labelText; anchors.left:parent.left; anchors.right:percent.left
            anchors.rightMargin:Style.space(12); anchors.verticalCenter:parent.verticalCenter
            text:root.label; textFormat:Text.PlainText; wrapMode:Text.Wrap
            color:Color.popups.text; font.family:Style.font.family; font.pixelSize:Style.font.body
        }
        Text {
            id:percent; anchors.right:reset.left; anchors.rightMargin:Style.space(8); anchors.verticalCenter:parent.verticalCenter
            text:root.value + "%"; color:root.accent
            font.family:Style.font.family; font.pixelSize:Style.font.body
        }
        ResetButton {
            id:reset; anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter
            words:root.words; label:root.label; valueText:root.defaultValue + "%"; accent:root.accent
            modified:root.modified; onResetRequested:root.resetRequested(); onEnsureVisible:root.ensureVisible()
        }
    }
    QQC.Slider {
        id:slider; width:parent.width; from:root.from; to:root.to; stepSize:root.stepSize
        value:root.value; palette.highlight:root.accent
        Accessible.name:root.label
        onMoved: { root.changed(value); value = Qt.binding(function() { return root.value; }); }
        onActiveFocusChanged: if (activeFocus) root.ensureVisible()
    }
}
