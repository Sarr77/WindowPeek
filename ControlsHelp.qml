import QtQuick
import qs.Commons
import "I18n.js" as I18n
import "Shortcuts.js" as Shortcuts
import "LogoWords.js" as LogoCopy

Column {
    id: root
    required property string language
    property var hostWidget: null
    property color accent: Color.accent
    property var shortcuts: ({})
    property bool doubleClickExpand: false
    readonly property var words: Shortcuts.applyWords(I18n.words(language), shortcuts)
    spacing: Style.space(12)
    Repeater {
        model: [
            {title: root.words.settingsList, entries: [root.doubleClickExpand ? root.words.doubleClickExpandHelp : root.words.controlsBar,
                root.words.guideSearch, root.words.guideFocus, root.words.controlsPrivacy,
                root.doubleClickExpand ? "" : root.words.controlsBlank, root.words.controlsWheel].filter(function(text) { return text !== ""; })},
            {title: root.words.guideMoveTitle || root.words.moveTo, entries: [I18n.format(root.words.guideMove || root.words.moveHint, {shortcut: Shortcuts.display(Shortcuts.normalize(root.shortcuts).moveMouse)}), root.words.bringHint]},
            {title: root.words.controlsKeyboard, entries: [root.words.searchWindows + "\n" + root.words.keyboardHint,
                root.words.controlsWindowKeys, root.words.controlsPaging, root.words.controlsWindowShortcuts, root.words.controlsTab, root.words.controlsActivate, root.words.controlsDropdown,
                root.words.controlsShortcut]},
            {title: root.words.settings, entries: [root.words.guidePin ? I18n.format(root.words.guidePin, {pin: root.words.pinPanel, unpin: root.words.unpinPanel, close: root.words.closePanel}) : root.words.pinPanelHelp,
                root.words.controlsClose,
                root.words.controls + " → " + root.words.shortcutsTitle + "\n" + root.words.shortcutsSummary,
                root.words.settingsPersonalization + " → " + root.words.picturesAndGifs + "\n" + LogoCopy.words(root.language).adjust,
                root.words.controlsColor]}
        ].filter(function(section) { return typeof section.title === "string" && section.title.length > 0; })
        delegate: SettingsSection {
            id: section
            required property int index
            required property var modelData
            objectName: "supportSection" + index
            width: root.width; title: modelData ? modelData.title : ""; accent: root.accent
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            Column {
                property var entries: section.modelData ? section.modelData.entries.filter(function(text) {
                    return typeof text === "string" && text.length > 0;
                }) : []
                width: root.width - Style.space(16); x: Style.space(8); spacing: Style.space(12)
                Repeater {
                    model: parent.entries
                    delegate: ReadableText {
                        required property string modelData
                        width: parent.width; text: modelData; textFormat: Text.PlainText
                        wrapMode: Text.Wrap; horizontalAlignment: Text.AlignLeft
                        textColor: Color.popups.text; lineHeight: 1.2
                        font.family: Style.font.family; font.pixelSize: Style.font.body + Style.space(1)
                    }
                }
            }
        }
    }
}
