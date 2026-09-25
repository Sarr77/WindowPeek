import QtQuick
import qs.Commons
import "I18n.js" as I18n

// The owner decides whether Reset saves immediately or changes an editor draft.
Item {
    id: root
    property var hostWidget: null
    required property var words
    required property string valueText
    property string label: ""
    property string description: ""
    property bool showReset: true
    property bool modified: false
    property color accent: Color.accent
    signal resetRequested()
    signal ensureVisible()
    implicitHeight: Math.max(captions.implicitHeight, showReset ? resetButton.height : 0)

    Column {
        id: captions
        anchors.left: parent.left
        anchors.right: root.showReset ? resetButton.left : parent.right
        anchors.rightMargin: root.showReset ? Style.space(12) : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)
        ReadableText {
            objectName: "defaultCaption"
            width: parent.width
            text: I18n.format(root.words.defaultValue, {value: root.valueText})
            textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
            textColor: Qt.alpha(Color.popups.text, 0.75)
            font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        ReadableText {
            width: parent.width; visible: root.description !== ""; text: root.description
            textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
            textColor: Qt.alpha(Color.popups.text, 0.65)
            font.family: Style.font.family; font.pixelSize: Style.font.body
        }
    }
    ResetButton {
        hostWidget: root.hostWidget
        id: resetButton; objectName: "resetDefaultButton"
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        words: root.words; valueText: root.valueText; label: root.label
        visible: root.showReset; modified: root.modified; accent: root.accent
        onResetRequested: root.resetRequested()
        onEnsureVisible: root.ensureVisible()
    }
}
