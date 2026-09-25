import QtQuick
import qs.Commons
import "I18n.js" as I18n

HintButton {
    id: root
    objectName: "resetDefaultButton"
    required property var words
    required property string valueText
    property string label: ""
    property bool modified: false
    signal resetRequested()
    signal ensureVisible()
    width: Style.space(32); height: Style.space(32)
    text: "↺"; fontSize: Style.font.subtitle
    hintText: words.resetValue + " · " + I18n.format(words.defaultValue, {value: valueText})
    // Keep the default value discoverable on hover without saving it again.
    focusable: modified || activeFocus
    foreground: hot || activeFocus ? accent : Qt.alpha(Color.popups.text, modified ? 0.95 : 0.7)
    Accessible.role: Accessible.Button
    Accessible.name: words.resetValue + (label ? " · " + label : "")
    Accessible.description: I18n.format(words.defaultValue, {value: valueText})
    Accessible.onPressAction: if (enabled && modified) resetRequested()
    onClicked: if (enabled && modified) resetRequested()
    onActiveFocusChanged: if (activeFocus) ensureVisible()
}
