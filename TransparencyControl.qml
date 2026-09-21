import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "I18n.js" as I18n

Column {
    id: root
    required property var words
    property color accent: Color.accent
    property int value: 8
    property int defaultValue: 8
    signal changed(int value)
    signal ensureVisible()
    spacing: Style.space(4)
    function choose(next) {
        changed(Math.max(0, Math.min(100, Math.round(next))));
        slider.value = Qt.binding(function() { return root.value; });
    }
    Item {
        width: parent.width; height: Math.max(Style.space(32), label.implicitHeight)
        Text {
            id: label
            anchors.left: parent.left; anchors.right: percent.left; anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: root.words.transparency; textFormat: Text.PlainText; wrapMode: Text.Wrap
            color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        Text {
            id: percent; objectName: "transparencyPercent"
            anchors.right: reset.left; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter
            text: root.value + "%"; textFormat: Text.PlainText
            color: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        ResetButton {
            id: reset
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            words: root.words; valueText: root.defaultValue + "%"; label: root.words.transparency; accent: root.accent
            modified: root.value !== root.defaultValue
            onResetRequested: root.choose(root.defaultValue)
            onEnsureVisible: root.ensureVisible()
        }
    }
    Item {
        width: parent.width; height: Math.max(slider.implicitHeight, caption.implicitHeight)
        QQC.Slider {
            id: slider; objectName: "transparencySlider"
            anchors.left: parent.left; anchors.right: caption.left; anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            from: 0; to: 100; stepSize: 1; snapMode: QQC.Slider.SnapAlways
            value: root.value; palette.highlight: root.accent
            Accessible.name: root.words.transparency
            onMoved: root.choose(value)
            onActiveFocusChanged: if (activeFocus) root.ensureVisible()
        }
        Text {
            id: caption
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.45)
            text: I18n.format(root.words.defaultValue, {value: root.defaultValue + "%"})
            textFormat: Text.PlainText; wrapMode: Text.Wrap
            color: Qt.alpha(Color.popups.text, 0.7); font.family: Style.font.family; font.pixelSize: Style.font.body
        }
    }
}
