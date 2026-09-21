import QtQuick
import qs.Commons
import "I18n.js" as I18n
import "Shortcuts.js" as Shortcuts

Column {
    id: root
    required property string language
    property color accent: Color.accent
    property var shortcuts: ({})
    readonly property var words: Shortcuts.applyWords(I18n.words(language), shortcuts)
    spacing: Style.space(16)
    Repeater {
        model: [
            {title: root.words.controlsMouse, entries: [root.words.controlsBar, root.words.focusHint,
                root.words.chooseMoveHint, root.words.bringHint, root.words.controlsPrivacy,
                root.words.controlsBlank, root.words.controlsClose, root.words.controlsWheel]},
            {title: root.words.controlsKeyboard, entries: [root.words.searchWindows + "\n" + root.words.keyboardHint,
                root.words.controlsWindowKeys, root.words.controlsPaging, root.words.controlsWindowShortcuts, root.words.controlsTab, root.words.controlsActivate, root.words.controlsDropdown,
                root.words.controlsColor, root.words.controlsShortcut]}
        ]
        delegate: Column {
            required property var modelData
            width: root.width; spacing: Style.space(12)
            Text {
                width: parent.width; text: parent.modelData.title; textFormat: Text.PlainText
                wrapMode: Text.Wrap; color: root.accent
                font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
            }
            Repeater {
                model: parent.modelData.entries
                delegate: Text {
                    required property string modelData
                    width: root.width; text: modelData; textFormat: Text.PlainText
                    wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
                    color: Qt.alpha(Color.popups.text, 0.9); lineHeight: 1.2
                    font.family: Style.font.family; font.pixelSize: Style.font.body + Style.space(1)
                }
            }
        }
    }
}
