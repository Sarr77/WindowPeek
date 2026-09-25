import QtQuick
import qs.Ui as Ui
import qs.Commons
import "I18n.js" as I18n

Column {
    id: root
    required property string label
    required property string helpText
    property var hostWidget: null
    required property var words
    property int value: 400
    property color accent: Color.accent
    signal changed(int value)
    signal ensureVisible()
    spacing: Style.space(6)
    opacity: enabled ? 1 : 0.5

    function choose(next) {
        changed(Math.max(0, Math.min(2000, Math.round(next))));
        // The owner updates value only after a successful durable save.
        field.text = String(value);
    }
    function commit() {
        if (field.acceptableInput && Number(field.text) !== value) choose(Number(field.text));
        else field.text = String(value);
    }
    onValueChanged: field.text = String(value)

    Item {
        width: parent.width
        readonly property bool stacked: width < Style.space(360)
        height: stacked ? caption.implicitHeight + controls.height + Style.space(6)
            : Math.max(caption.implicitHeight, controls.height)
        ReadableText {
            id: caption; objectName: "delayCaption"
            anchors.left: parent.left
            y: parent.stacked ? 0 : (parent.height - height) / 2
            width: parent.stacked ? parent.width : parent.width - controls.width - Style.space(12)
            text: root.label; textFormat: Text.PlainText
            wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
            textColor: Qt.alpha(Color.popups.text, 0.85)
            font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        Item {
            id: controls; objectName: "delayControls"
            width: buttons.implicitWidth; height: buttons.implicitHeight
            anchors.right: parent.right
            y: parent.stacked ? parent.height - height : (parent.height - height) / 2
            Row {
                id: buttons
                anchors.fill: parent
                spacing: Style.space(6)
                // Numbers and +/- keep their conventional direction in every language.
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true
                ReadableButton {
                    width: Style.space(34); height: Style.space(32); text: "−"; accent: root.accent; focusable: true
                    enabled: root.value > 0
                    Accessible.name: root.label + " −50 ms"
                    onClicked: root.choose(root.value - 50)
                    onActiveFocusChanged: if (activeFocus) root.ensureVisible()
                }
                EditField {
                    id: field; objectName: "delayInput"
                    width: Style.space(64); height: Style.space(32); text: String(root.value)
                    maximumLength: 4
                    validator: IntValidator { bottom: 0; top: 2000; locale: "C" }
                    inputMethodHints: Qt.ImhDigitsOnly
                    horizontalAlignment: TextInput.AlignHCenter
                    Accessible.name: root.label + " (ms)"
                    accent: root.accent
                    onEditingFinished: root.commit()
                    onActiveFocusChanged: {
                        if (activeFocus) root.ensureVisible();
                        else root.commit();
                    }
                }
                ReadableText {
                    text: "ms"; textColor: Qt.alpha(Color.popups.text, 0.8)
                    font.family: Style.font.family; font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                }
                ReadableButton {
                    width: Style.space(34); height: Style.space(32); text: "+"; accent: root.accent; focusable: true
                    enabled: root.value < 2000
                    Accessible.name: root.label + " +50 ms"
                    onClicked: root.choose(root.value + 50)
                    onActiveFocusChanged: if (activeFocus) root.ensureVisible()
                }
                ResetButton {
                    hostWidget: root.hostWidget
                    words: root.words; valueText: "400 ms"; label: root.label; accent: root.accent
                    modified: root.value !== 400 || field.text !== "400"
                    onResetRequested: root.choose(400)
                    onEnsureVisible: root.ensureVisible()
                }
            }
        }
    }
    ReadableText {
        width: parent.width
        text: root.helpText + " · " + I18n.format(root.words.defaultValue, {value: "400 ms"})
        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
        textColor: Qt.alpha(Color.popups.text, 0.7); font.family: Style.font.family; font.pixelSize: Style.font.body
    }
}
