import QtQuick
import qs.Commons
import "vendor/omarchy" as Choice
import "Settings.js" as Settings
import "I18n.js" as I18n

Item {
    id: root
    required property var hostWidget
    property string prefix: ""
    property real value: 0
    property string unit: "s"
    readonly property real factor: unit === "min" ? 60 : 1
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    height: cooldownUnits.implicitHeight
    ReadableText {
        anchors.left: parent.left; anchors.right: cooldownInput.left; anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: root.words.animationCooldown; textFormat: Text.PlainText; elide: Text.ElideRight
        textColor: Qt.alpha(Color.popups.text, 0.7)
        font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    EditField {
        id: cooldownInput; objectName: root.prefix + "LogoCooldown"
        anchors.right: cooldownUnits.left; anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(64); height: Style.space(24)
        font.pixelSize: Style.font.caption; verticalPadding: 0; horizontalPadding: Style.space(4)
        horizontalAlignment: TextInput.AlignHCenter; LayoutMirroring.enabled: false
        maximumLength: 12; selectByMouse: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
        validator: RegularExpressionValidator { regularExpression: /\d{1,5}([.,]\d{0,6})?/ }
        accent: root.hostWidget ? root.hostWidget.accent : Color.accent
        Accessible.name: root.words.animationCooldown + " (" + root.unit + ")"
        function resetText() { text = String(Number((root.value / root.factor).toFixed(6))); }
        function save() {
            var value = Number(text.replace(",", ".")) * root.factor;
            if (acceptableInput && value <= 86400 && root.hostWidget
                    && Settings.logoCooldown(value) !== root.value) {
                var values = {}; values[root.prefix + "LogoCooldown"] = Settings.logoCooldown(value);
                root.hostWidget.persistSettings(values);
            }
            resetText();
        }
        Component.onCompleted: resetText()
        onAccepted: save()
        onEditingFinished: Qt.callLater(function() { if (cooldownInput) cooldownInput.save(); })
        Connections {
            target: root
            function onValueChanged() { if (!cooldownInput.activeFocus) cooldownInput.resetText(); }
            function onUnitChanged() { cooldownInput.resetText(); }
        }
    }
    Choice.Dropdown {
        id: cooldownUnits; objectName: root.prefix + "LogoCooldownUnit"
        anchors.right: cooldownReset.left; anchors.rightMargin: Style.space(4)
        width: Style.space(76)
        hostWidget: root.hostWidget; uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
        accent: root.hostWidget ? root.hostWidget.accent : Color.accent
        showLabel: false; value: root.unit
        options: [{value:"s", label:"s"}, {value:"min", label:"min"}]
        onChanged: function(value) {
            if (!root.hostWidget) return;
            cooldownInput.save();
            var values = {}; values[root.prefix + "LogoCooldownUnit"] = value;
            root.hostWidget.persistSettings(values);
            cooldownUnits.value = Qt.binding(function() { return root.unit; });
            cooldownInput.resetText();
        }
    }
    ResetButton {
        id: cooldownReset; objectName: root.prefix + "LogoCooldownReset"
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: Style.space(24); height: Style.space(26)
        hostWidget: root.hostWidget; words: root.words
        label: root.words.animationCooldown; valueText: "0 " + root.unit
        modified: root.value !== 0
        accent: root.hostWidget ? root.hostWidget.accent : Color.accent
        onResetRequested: {
            cooldownInput.text = "0";
            var values = {}; values[root.prefix + "LogoCooldown"] = 0;
            root.hostWidget.persistSettings(values);
        }
    }
}
